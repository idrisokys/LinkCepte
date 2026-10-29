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
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
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

    // ---- Sürükle-bırak: sıralama + klasöre taşıma ----
    val listState = rememberLazyListState()
    val currentDir by rememberUpdatedState(current)
    var dragKey by remember { mutableStateOf<String?>(null) }   // sürüklenen satır
    var dragY by remember { mutableFloatStateOf(0f) }           // sürüklenen satırın merkezi (liste koordinatı)
    var dropKey by remember { mutableStateOf<String?>(null) }   // üzerine bırakılacak klasör
    var startOrder by remember { mutableStateOf(listOf<String>()) }

    fun dragStart(key: String) {
        val it = listState.layoutInfo.visibleItemsInfo.firstOrNull { x -> x.key == key } ?: return
        dragKey = key; dropKey = null
        dragY = it.offset + it.size / 2f
        startOrder = loaded?.map { x -> x.key } ?: emptyList()
    }
    fun dragMove(dy: Float) {
        val key = dragKey ?: return
        dragY += dy
        val l = loaded ?: return
        val vis = listState.layoutInfo.visibleItemsInfo
        val from = l.indexOfFirst { it.key == key }
        val me = vis.firstOrNull { it.key == key } ?: return
        if (from < 0 || me.index != from) return            // yerleşim henüz güncellenmedi
        val y = dragY.toInt()
        val over = vis.firstOrNull { it.key != key && y >= it.offset && y < it.offset + it.size }
        if (over == null) { dropKey = null; return }
        val target = l.getOrNull(over.index) ?: return
        val frac = (y - over.offset).toFloat() / over.size
        val down = over.index > from
        if (!l[from].isDir && target.isDir) {
            // Link klasörün ortasındaysa: klasöre bırakma. Karşı kenara geçerse: klasörü atla.
            if (frac in 0.2f..0.8f) { dropKey = target.key; return }
            dropKey = null
            if (!((down && frac > 0.8f) || (!down && frac < 0.2f))) return
        } else {
            dropKey = null
            if (!(if (down) frac > 0.5f else frac < 0.5f)) return
        }
        val m = l.toMutableList(); m.add(over.index, m.removeAt(from)); loaded = m
    }
    fun dragEnd(cancel: Boolean) {
        val key = dragKey ?: return
        val drop = dropKey
        dragKey = null; dropKey = null
        val l = loaded ?: return
        if (cancel) { tick++; return }
        val e = l.firstOrNull { it.key == key } ?: return
        val folder = drop?.let { d -> l.firstOrNull { it.key == d } }
        if (folder != null) {
            loaded = l.filter { it.key != key }
            scope.launch {
                val ok = lock.withLock { withContext(Dispatchers.IO) { Store.moveLink(ctx, e, folder.uri) } }
                tick++
                toast(if (ok) "“${e.name.removeSuffix(".url")}” → ${folder.name}" else "Taşınamadı")
            }
        } else if (l.map { it.key } != startOrder) {
            val names = l.map { it.name }
            val dir = currentDir
            run(reload = false) { Store.saveOrder(ctx, dir, names) }
        }
    }
    // Liste kenarına yaklaşınca otomatik kaydır
    LaunchedEffect(dragKey) {
        while (dragKey != null) {
            val info = listState.layoutInfo
            val edge = 120f
            val top = info.viewportStartOffset + edge
            val bottom = info.viewportEndOffset - edge
            val d = when {
                dragY < top -> -(((top - dragY) / edge) * 24f).coerceIn(4f, 24f)
                dragY > bottom -> (((dragY - bottom) / edge) * 24f).coerceIn(4f, 24f)
                else -> 0f
            }
            if (d != 0f) { listState.scrollBy(d); dragMove(0f) }
            delay(16)
        }
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
        LazyColumn(Modifier.padding(pad).fillMaxSize(), state = listState) {
            items(list, key = { it.key }) { e ->
                val sel = e.key in selected
                val dragging = e.key == dragKey
                val hot = e.key == dropKey
                Column(
                    Modifier
                        .then(if (dragging) Modifier else Modifier.animateItemPlacement())
                        .zIndex(if (dragging) 1f else 0f)
                        .graphicsLayer {
                            if (dragging) {
                                val info = listState.layoutInfo.visibleItemsInfo.firstOrNull { x -> x.key == e.key }
                                if (info != null) translationY = dragY - (info.offset + info.size / 2f)
                            }
                        }
                ) {
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
                        colors = ListItemDefaults.colors(containerColor = when {
                            hot -> MaterialTheme.colorScheme.primaryContainer
                            dragging -> MaterialTheme.colorScheme.surfaceVariant
                            sel -> MaterialTheme.colorScheme.secondaryContainer
                            else -> MaterialTheme.colorScheme.surface
                        }),
                        leadingContent = {
                            if (selecting && !e.isDir) Checkbox(sel, null)
                            else Icon(if (e.isDir) (if (hot) Icons.Default.FolderOpen else Icons.Default.Folder) else Icons.Default.Link, null)
                        },
                        headlineContent = { Text(e.name.removeSuffix(".url"), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        trailingContent = {
                            if (!selecting && editMode) Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton({ renaming = e }, Modifier.size(40.dp)) { Icon(Icons.Default.Edit, "Adı değiştir") }
                                IconButton({ toDelete = listOf(e) }, Modifier.size(40.dp)) { Icon(Icons.Default.Delete, "Sil") }
                                Icon(
                                    Icons.Default.DragHandle, "Sürükle",
                                    Modifier.size(48.dp).padding(12.dp).pointerInput(e.key) {
                                        detectDragGestures(
                                            onDragStart = { dragStart(e.key) },
                                            onDrag = { change, amount -> change.consume(); dragMove(amount.y) },
                                            onDragEnd = { dragEnd(false) },
                                            onDragCancel = { dragEnd(true) })
                                    })
                            }
                        })
                    HorizontalDivider()
                }
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
