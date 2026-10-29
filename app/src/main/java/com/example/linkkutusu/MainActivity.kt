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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

private val DarkScheme = darkColorScheme()

class MainActivity : ComponentActivity() {
    private val resumes = mutableIntStateOf(0)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme(colorScheme = DarkScheme) { Surface(Modifier.fillMaxSize()) { App(resumes.intValue) } } }
    }
    override fun onResume() {
        super.onResume()
        resumes.intValue++
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun App(resume: Int = 0) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val lock = remember { Mutex() }
    var root by remember { mutableStateOf(Store.root(ctx)) }
    var stack by remember { mutableStateOf(listOf<Entry>()) }
    var tick by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var dialog by remember { mutableStateOf<String?>(null) }
    var toDelete by remember { mutableStateOf<List<Entry>?>(null) }
    var renaming by remember { mutableStateOf<Entry?>(null) }
    var menu by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf<String?>(null) }
    var editMode by remember { mutableStateOf(false) }
    var linkText by remember { mutableStateOf("") }
    val clipboard = LocalClipboardManager.current
    val focus = LocalFocusManager.current

    fun toast(s: String) = Toast.makeText(ctx, s, Toast.LENGTH_SHORT).show()
    fun run(reload: Boolean = true, block: () -> Unit) {
        scope.launch { lock.withLock { withContext(Dispatchers.IO) { block() } }; if (reload) tick++ }
    }

    val pickFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri != null) {
            if (Store.setRoot(ctx, uri)) { root = Store.root(ctx); stack = emptyList(); selected = emptySet(); tick++ }
            else toast("Bu klasöre yazılamıyor, başka bir klasör seçin")
        }
    }

    val rootUri = root
    if (rootUri == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Link Cepte", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(12.dp))
            Text("Linklerin kaydedileceği klasörü seçin.")
            Spacer(Modifier.height(16.dp))
            Button(onClick = { pickFolder.launch(null) }) { Text("Klasör seç") }
        }
        return
    }

    val current = stack.lastOrNull()?.uri ?: rootUri
    var loaded by remember(current) { mutableStateOf<List<Entry>?>(null) }
    LaunchedEffect(current, tick, resume) { loaded = withContext(Dispatchers.IO) { Store.list(ctx, current) } }
    val list = loaded ?: emptyList()
    val selecting = selected.isNotEmpty()
    BackHandler(selecting || stack.isNotEmpty()) {
        if (selecting) selected = emptySet() else stack = stack.dropLast(1)
    }

    fun swap(i: Int, d: Int) {
        val l = list.toMutableList(); val j = i + d
        if (j !in l.indices) return
        l.add(j, l.removeAt(i)); loaded = l
        val names = l.map { it.name }
        run(reload = false) { Store.saveOrder(ctx, current, names) }
    }
    fun open(e: Entry) {
        scope.launch {
            val u = withContext(Dispatchers.IO) { Store.readUrl(ctx, e.uri) }
            if (u == null) {
                val t = withContext(Dispatchers.IO) { Store.readText(ctx, e.uri) }
                if (t != null) note = t else toast("Link okunamadı")
            }
            else try { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) } catch (ex: Exception) { toast("Link açılamadı") }
        }
    }
    fun addFromText() {
        val text = linkText.trim()
        if (text.isEmpty()) return
        linkText = ""
        focus.clearFocus()
        scope.launch {
            val ok = withContext(Dispatchers.IO) { Store.addFromText(ctx, current, text) }
            tick++
            toast(if (ok) "Eklendi" else "Eklenemedi")
        }
    }
    fun toggle(e: Entry) { selected = if (e.key in selected) selected - e.key else selected + e.key }

    Scaffold(bottomBar = {
        if (!selecting) Surface(tonalElevation = 3.dp) {
            Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    linkText, { linkText = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Link veya metin yapıştır") },
                    singleLine = false, maxLines = 3,
                    trailingIcon = {
                        IconButton({ clipboard.getText()?.text?.let { linkText = it } }) { Icon(Icons.Default.ContentPaste, "Yapıştır") }
                    },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                IconButton({ addFromText() }, enabled = linkText.isNotBlank()) { Icon(Icons.Default.Add, "Ekle") }
            }
        }
    }, topBar = {
        if (selecting) TopAppBar(
            title = { Text("${selected.size} seçili") },
            navigationIcon = { IconButton({ selected = emptySet() }) { Icon(Icons.Default.Close, "İptal") } },
            actions = {
                IconButton({ dialog = "move" }) { Icon(Icons.Default.DriveFileMove, "Taşı") }
                IconButton({ toDelete = list.filter { it.key in selected } }) { Icon(Icons.Default.Delete, "Sil") }
            })
        else TopAppBar(
            title = { Text(if (stack.isEmpty()) "Link Cepte" else stack.last().name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = { if (stack.isNotEmpty()) IconButton({ stack = stack.dropLast(1) }) { Icon(Icons.Default.ArrowBack, "Geri") } },
            actions = {
                IconButton({ tick++ }) { Icon(Icons.Default.Refresh, "Yenile") }
                IconButton({ editMode = !editMode }) {
                    Icon(Icons.Default.Edit, "Düzenle", tint = if (editMode) MaterialTheme.colorScheme.primary else LocalContentColor.current)
                }
                IconButton({ dialog = "folder" }) { Icon(Icons.Default.CreateNewFolder, "Klasör") }
                IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, "Menü") }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem({ Text("Klasörü değiştir") }, { menu = false; pickFolder.launch(null) })
                }
            })
    }) { pad ->
        if (loaded != null && list.isEmpty()) Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) {
            Text("Burada henüz bir şey yok. Alttaki alana link veya metin yapıştırın ya da tarayıcıda Paylaş → Link Cepte'yi seçin.")
        }
        LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            itemsIndexed(list, key = { _, e -> e.key }) { i, e ->
                val sel = e.key in selected
                ListItem(
                    modifier = Modifier.combinedClickable(
                        onClick = {
                            when {
                                selecting -> if (!e.isDir) toggle(e)
                                e.isDir -> stack = stack + e
                                else -> open(e)
                            }
                        },
                        onLongClick = { if (!e.isDir) toggle(e) }),
                    colors = ListItemDefaults.colors(containerColor = if (sel) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface),
                    leadingContent = {
                        if (selecting && !e.isDir) Checkbox(sel, null)
                        else Icon(if (e.isDir) Icons.Default.Folder else Icons.Default.Link, null)
                    },
                    headlineContent = { Text(e.name.removeSuffix(".url"), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    trailingContent = {
                        if (!selecting && editMode) Row {
                            IconButton({ renaming = e }, Modifier.size(40.dp)) { Icon(Icons.Default.Edit, "Adı değiştir") }
                            IconButton({ swap(i, -1) }, Modifier.size(40.dp), enabled = i > 0) { Icon(Icons.Default.KeyboardArrowUp, "Yukarı") }
                            IconButton({ swap(i, 1) }, Modifier.size(40.dp), enabled = i < list.size - 1) { Icon(Icons.Default.KeyboardArrowDown, "Aşağı") }
                            IconButton({ toDelete = listOf(e) }, Modifier.size(40.dp)) { Icon(Icons.Default.Delete, "Sil") }
                        }
                    })
                HorizontalDivider()
            }
        }
    }

    note?.let { t ->
        AlertDialog(
            onDismissRequest = { note = null },
            text = { Text(t, modifier = Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) },
            confirmButton = { TextButton({ note = null }) { Text("Kapat") } },
            dismissButton = { TextButton({ clipboard.setText(AnnotatedString(t)); toast("Kopyalandı") }) { Text("Kopyala") } })
    }

    renaming?.let { r ->
        var t by remember(r) { mutableStateOf(r.name.removeSuffix(".url")) }
        AlertDialog(
            onDismissRequest = { renaming = null },
            title = { Text("Adı değiştir") },
            text = { OutlinedTextField(t, { t = it }, singleLine = true) },
            confirmButton = {
                TextButton({
                    val n = t; renaming = null
                    scope.launch {
                        val ok = lock.withLock { withContext(Dispatchers.IO) { Store.rename(ctx, current, r, n) } }
                        tick++
                        if (!ok) toast("Ad değiştirilemedi (aynı adda öğe olabilir)")
                    }
                }, enabled = t.isNotBlank()) { Text("Kaydet") }
            },
            dismissButton = { TextButton({ renaming = null }) { Text("İptal") } })
    }

    toDelete?.let { del ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text("Silinsin mi?") },
            text = {
                Text(if (del.size == 1) "“${del[0].name.removeSuffix(".url")}” silinecek." + (if (del[0].isDir) " Klasörün içindekiler de silinir." else "")
                else "${del.size} öğe silinecek.")
            },
            confirmButton = { TextButton({ toDelete = null; selected = emptySet(); run { del.forEach { Store.delete(ctx, it.uri) } } }) { Text("Sil") } },
            dismissButton = { TextButton({ toDelete = null }) { Text("İptal") } })
    }

    if (dialog == "folder") {
        var title by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("Yeni klasör") },
            text = { OutlinedTextField(title, { title = it }, label = { Text("Klasör adı") }, singleLine = true) },
            confirmButton = { TextButton({ val n = title; dialog = null; run { Store.addFolder(ctx, current, n) } }, enabled = title.isNotBlank()) { Text("Oluştur") } },
            dismissButton = { TextButton({ dialog = null }) { Text("İptal") } })
    }

    if (dialog == "move") MoveDialog(ctx, rootUri, current, { dialog = null }) { target ->
        val files = list.filter { it.key in selected }
        dialog = null; selected = emptySet()
        scope.launch {
            val ok = lock.withLock { withContext(Dispatchers.IO) { files.count { Store.moveLink(ctx, it, target) } } }
            tick++
            toast(if (ok == files.size) "$ok link taşındı" else "$ok/${files.size} link taşınabildi")
        }
    }
}

@Composable
fun MoveDialog(ctx: android.content.Context, root: Uri, current: Uri, onDismiss: () -> Unit, onPick: (Uri) -> Unit) {
    var stack by remember { mutableStateOf(listOf<Entry>()) }
    val dir = stack.lastOrNull()?.uri ?: root
    val scope = rememberCoroutineScope()
    var creating by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var folders by remember(dir) { mutableStateOf(emptyList<Entry>()) }
    LaunchedEffect(dir) { folders = withContext(Dispatchers.IO) { Store.list(ctx, dir).filter { it.isDir } } }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Taşı: " + (stack.lastOrNull()?.name ?: "Ana liste")) },
        text = {
            LazyColumn(Modifier.heightIn(max = 320.dp)) {
                if (stack.isNotEmpty()) item {
                    ListItem(modifier = Modifier.clickable { stack = stack.dropLast(1) },
                        leadingContent = { Icon(Icons.Default.ArrowBack, null) }, headlineContent = { Text("Üst klasör") })
                }
                item {
                    if (!creating) ListItem(modifier = Modifier.clickable { creating = true },
                        leadingContent = { Icon(Icons.Default.CreateNewFolder, null) }, headlineContent = { Text("Yeni klasör oluştur") })
                    else Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(newName, { newName = it }, label = { Text("Klasör adı") }, singleLine = true, modifier = Modifier.weight(1f))
                        TextButton(enabled = newName.isNotBlank(), onClick = {
                            val n = newName
                            val before = folders.map { it.uri }.toSet()
                            creating = false; newName = ""
                            scope.launch {
                                val all = withContext(Dispatchers.IO) { Store.addFolder(ctx, dir, n); Store.list(ctx, dir).filter { it.isDir } }
                                folders = all
                                all.firstOrNull { it.uri !in before }?.let { stack = stack + it }
                            }
                        }) { Text("Oluştur") }
                    }
                }
                items(folders, key = { it.key }) { f ->
                    ListItem(modifier = Modifier.clickable { stack = stack + f },
                        leadingContent = { Icon(Icons.Default.Folder, null) }, headlineContent = { Text(f.name, maxLines = 1, overflow = TextOverflow.Ellipsis) })
                }
            }
        },
        confirmButton = { TextButton({ onPick(dir) }, enabled = dir != current) { Text("Buraya taşı") } },
        dismissButton = { TextButton(onDismiss) { Text("İptal") } })
}
