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
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun App() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var root by remember { mutableStateOf(Store.root(ctx)) }
    var stack by remember { mutableStateOf(listOf<DocumentFile>()) }
    var tick by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var folderDialog by remember { mutableStateOf(false) }
    var moveDialog by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }

    val pickFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri != null) { Store.setRoot(ctx, uri); root = Store.root(ctx); stack = emptyList(); selected = emptySet(); tick++ }
    }

    if (root == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Link Cepte", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(12.dp))
            Text("Linklerin kaydedileceği klasörü seçin.")
            Spacer(Modifier.height(16.dp))
            Button(onClick = { pickFolder.launch(null) }) { Text("Klasör seç") }
        }
        return
    }

    val current = stack.lastOrNull() ?: root!!
    BackHandler(selected.isNotEmpty() || stack.isNotEmpty()) {
        if (selected.isNotEmpty()) selected = emptySet() else stack = stack.dropLast(1)
    }
    val items = remember(current, tick) { Store.list(ctx, current) }
    val selecting = selected.isNotEmpty()

    Scaffold(topBar = {
        if (selecting) TopAppBar(
            title = { Text("${selected.size} seçili") },
            navigationIcon = { IconButton({ selected = emptySet() }) { Icon(Icons.Default.Close, "İptal") } },
            actions = {
                IconButton({ moveDialog = true }) { Icon(Icons.Default.DriveFileMove, "Taşı") }
                IconButton({ items.filter { it.name in selected }.forEach { it.delete() }; selected = emptySet(); tick++ }) { Icon(Icons.Default.Delete, "Sil") }
            })
        else TopAppBar(
            title = { Text(if (stack.isEmpty()) "Link Cepte" else current.name ?: "") },
            navigationIcon = { if (stack.isNotEmpty()) IconButton({ stack = stack.dropLast(1) }) { Icon(Icons.Default.ArrowBack, null) } },
            actions = {
                IconButton({ folderDialog = true }) { Icon(Icons.Default.CreateNewFolder, "Klasör") }
                IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, null) }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem({ Text("Klasörü değiştir") }, { menu = false; pickFolder.launch(null) })
                }
            })
    }) { pad ->
        if (items.isEmpty()) Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) {
            Text("Burada link yok. Tarayıcıda Paylaş → Link Cepte ile ekleyin.")
        }
        LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            itemsIndexed(items, key = { _, f -> f.uri.toString() }) { i, f ->
                val isDir = f.isDirectory
                val name = f.name!!
                ListItem(
                    modifier = Modifier.combinedClickable(
                        onClick = {
                            when {
                                selecting && !isDir -> selected = if (name in selected) selected - name else selected + name
                                isDir -> if (!selecting) { stack = stack + f }
                                else -> Store.readUrl(ctx, f)?.let { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) } }
                            }
                        },
                        onLongClick = { if (!isDir) selected = if (name in selected) selected - name else selected + name }),
                    leadingContent = {
                        if (selecting && !isDir) Checkbox(name in selected, null)
                        else Icon(if (isDir) Icons.Default.Folder else Icons.Default.Link, null)
                    },
                    headlineContent = { Text(name.removeSuffix(".url")) },
                    trailingContent = {
                        if (!selecting) Row {
                            IconButton({ Store.move(ctx, current, i, -1); tick++ }, enabled = i > 0) { Icon(Icons.Default.KeyboardArrowUp, "Yukarı") }
                            IconButton({ Store.move(ctx, current, i, 1); tick++ }, enabled = i < items.size - 1) { Icon(Icons.Default.KeyboardArrowDown, "Aşağı") }
                            IconButton({ f.delete(); tick++ }) { Icon(Icons.Default.Delete, "Sil") }
                        }
                    })
                HorizontalDivider()
            }
        }
    }

    if (folderDialog) {
        var title by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { folderDialog = false },
            title = { Text("Yeni klasör") },
            text = { OutlinedTextField(title, { title = it }, label = { Text("Klasör adı") }, singleLine = true) },
            confirmButton = { TextButton({ Store.addFolder(current, title); folderDialog = false; tick++ }, enabled = title.isNotBlank()) { Text("Oluştur") } },
            dismissButton = { TextButton({ folderDialog = false }) { Text("İptal") } })
    }

    if (moveDialog) MoveDialog(ctx, root!!, current, { moveDialog = false }) { target ->
        val files = items.filter { it.name in selected }
        moveDialog = false
        scope.launch {
            val ok = withContext(Dispatchers.IO) { files.count { Store.moveLink(ctx, it, target) } }
            selected = emptySet(); tick++
            Toast.makeText(ctx, "$ok link taşındı", Toast.LENGTH_SHORT).show()
        }
    }
}

@Composable
fun MoveDialog(ctx: android.content.Context, root: DocumentFile, current: DocumentFile, onDismiss: () -> Unit, onPick: (DocumentFile) -> Unit) {
    var stack by remember { mutableStateOf(listOf<DocumentFile>()) }
    val dir = stack.lastOrNull() ?: root
    val folders = remember(dir) { Store.list(ctx, dir).filter { it.isDirectory } }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Taşı: " + (if (stack.isEmpty()) "Ana liste" else dir.name ?: "")) },
        text = {
            LazyColumn(Modifier.heightIn(max = 320.dp)) {
                if (stack.isNotEmpty()) item {
                    ListItem(Modifier.combinedClickableSimple { stack = stack.dropLast(1) },
                        leadingContent = { Icon(Icons.Default.ArrowBack, null) }, headlineContent = { Text("Üst klasör") })
                }
                items(folders, key = { it.uri.toString() }) { f ->
                    ListItem(Modifier.combinedClickableSimple { stack = stack + f },
                        leadingContent = { Icon(Icons.Default.Folder, null) }, headlineContent = { Text(f.name ?: "") })
                }
            }
        },
        confirmButton = { TextButton({ onPick(dir) }, enabled = dir.uri != current.uri) { Text("Buraya taşı") } },
        dismissButton = { TextButton(onDismiss) { Text("İptal") } })
}

@OptIn(ExperimentalFoundationApi::class)
fun Modifier.combinedClickableSimple(onClick: () -> Unit) = this.combinedClickable(onClick = onClick)
