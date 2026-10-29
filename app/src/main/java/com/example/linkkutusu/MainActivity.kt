package com.example.linkkutusu

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { App() } }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var root by remember { mutableStateOf(Store.root(ctx)) }
    var stack by remember { mutableStateOf(listOf<DocumentFile>()) }
    var tick by remember { mutableIntStateOf(0) }
    var dialog by remember { mutableStateOf<String?>(null) } // "link" | "folder"
    var menu by remember { mutableStateOf(false) }

    val pickFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri != null) { Store.setRoot(ctx, uri); root = Store.root(ctx); stack = emptyList(); tick++ }
    }
    val doBackup = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri: Uri? ->
        val r = root
        if (uri != null && r != null) scope.launch {
            withContext(Dispatchers.IO) { ctx.contentResolver.openOutputStream(uri)?.let { Store.backup(ctx, r, it) } }
            Toast.makeText(ctx, "Yedek alındı", Toast.LENGTH_SHORT).show()
        }
    }
    val doRestore = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        val r = root
        if (uri != null && r != null) scope.launch {
            withContext(Dispatchers.IO) { ctx.contentResolver.openInputStream(uri)?.let { Store.restore(ctx, r, it) } }
            stack = emptyList(); tick++
            Toast.makeText(ctx, "Yedek geri yüklendi", Toast.LENGTH_SHORT).show()
        }
    }

    if (root == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Link Kutusu", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(12.dp))
            Text("Linklerin kaydedileceği klasörü seçin.")
            Spacer(Modifier.height(16.dp))
            Button(onClick = { pickFolder.launch(null) }) { Text("Klasör seç") }
        }
        return
    }

    val current = stack.lastOrNull() ?: root!!
    BackHandler(stack.isNotEmpty()) { stack = stack.dropLast(1) }
    val items = remember(current, tick) { Store.list(ctx, current) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (stack.isEmpty()) "Linklerim" else current.name ?: "") },
                navigationIcon = { if (stack.isNotEmpty()) IconButton({ stack = stack.dropLast(1) }) { Icon(Icons.Default.ArrowBack, null) } },
                actions = {
                    IconButton({ dialog = "folder" }) { Icon(Icons.Default.CreateNewFolder, "Klasör") }
                    IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, null) }
                    DropdownMenu(menu, { menu = false }) {
                        DropdownMenuItem({ Text("Yedekle") }, { menu = false; doBackup.launch("linkler-yedek.zip") })
                        DropdownMenuItem({ Text("Geri yükle") }, { menu = false; doRestore.launch(arrayOf("application/zip", "application/octet-stream")) })
                        DropdownMenuItem({ Text("Klasörü değiştir") }, { menu = false; pickFolder.launch(null) })
                    }
                })
        },
        floatingActionButton = { FloatingActionButton({ dialog = "link" }) { Icon(Icons.Default.Add, "Link ekle") } }
    ) { pad ->
        LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            itemsIndexed(items, key = { _, f -> f.uri.toString() }) { i, f ->
                val isDir = f.isDirectory
                ListItem(
                    modifier = Modifier.clickable {
                        if (isDir) stack = stack + f
                        else Store.readUrl(ctx, f)?.let { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) } }
                    },
                    leadingContent = { Icon(if (isDir) Icons.Default.Folder else Icons.Default.Link, null) },
                    headlineContent = { Text(f.name!!.removeSuffix(".url")) },
                    trailingContent = {
                        Row {
                            IconButton({ Store.move(ctx, current, i, -1); tick++ }, enabled = i > 0) { Icon(Icons.Default.KeyboardArrowUp, "Yukarı") }
                            IconButton({ Store.move(ctx, current, i, 1); tick++ }, enabled = i < items.size - 1) { Icon(Icons.Default.KeyboardArrowDown, "Aşağı") }
                            IconButton({ f.delete(); tick++ }) { Icon(Icons.Default.Delete, "Sil") }
                        }
                    })
                HorizontalDivider()
            }
        }
    }

    dialog?.let { kind ->
        var title by remember { mutableStateOf("") }
        var url by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text(if (kind == "link") "Link ekle" else "Yeni klasör") },
            text = {
                Column {
                    OutlinedTextField(title, { title = it }, label = { Text(if (kind == "link") "Başlık" else "Klasör adı") }, singleLine = true)
                    if (kind == "link") OutlinedTextField(url, { url = it }, label = { Text("URL") }, singleLine = true)
                }
            },
            confirmButton = {
                TextButton({
                    if (kind == "link") Store.addLink(ctx, current, title.ifBlank { url }, url.trim()) else Store.addFolder(current, title)
                    dialog = null; tick++
                }, enabled = title.isNotBlank() || url.isNotBlank()) { Text("Kaydet") }
            },
            dismissButton = { TextButton({ dialog = null }) { Text("İptal") } })
    }
}
