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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.CircleShape
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
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
    var renaming by remember { mutableStateOf<Entry?>(null) }
    var renameText by remember { mutableStateOf("") }
    val renameFocus = remember { FocusRequester() }
    var menu by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf<String?>(null) }
    var linkText by remember { mutableStateOf("") }
    var searchQuery by remember { mutableStateOf<String?>(null) }   // null = normal liste
    var hits by remember { mutableStateOf<List<Hit>?>(null) }       // null = aranıyor
    var searchJob by remember { mutableStateOf<Job?>(null) }
    val clipboard = LocalClipboardManager.current
    val focus = LocalFocusManager.current

    val maxChars = 220      // ad değiştirme sınırı
    val addMax = 220        // alttaki ekleme alanı sınırı
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
    val rn = renaming?.takeIf { selected.size == 1 && it.key in selected }   // geçerli ad değiştirme
    BackHandler(selecting || searchQuery != null || stack.isNotEmpty()) {
        when {
            rn != null -> renaming = null
            selecting -> selected = emptySet()
            searchQuery != null -> { searchJob?.cancel(); searchQuery = null; hits = null }
            else -> stack = stack.dropLast(1)
        }
    }

    // ---- Sürükle-bırak: yalnızca sıralama ----
    val listState = rememberLazyListState()
    val currentDir by rememberUpdatedState(current)
    var dragKey by remember { mutableStateOf<String?>(null) }   // sürüklenen satır
    var dragY by remember { mutableFloatStateOf(0f) }           // sürüklenen satırın merkezi (liste koordinatı)
    var startOrder by remember { mutableStateOf(listOf<String>()) }

    fun dragStart(key: String) {
        val it = listState.layoutInfo.visibleItemsInfo.firstOrNull { x -> x.key == key } ?: return
        dragKey = key
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
        val over = vis.firstOrNull { it.key != key && y >= it.offset && y < it.offset + it.size } ?: return
        val frac = (y - over.offset).toFloat() / over.size
        val down = over.index > from
        if (!(if (down) frac > 0.5f else frac < 0.5f)) return
        val m = l.toMutableList(); m.add(over.index, m.removeAt(from)); loaded = m
    }
    fun dragEnd(cancel: Boolean) {
        if (dragKey == null) return
        dragKey = null
        val l = loaded ?: return
        if (cancel) { tick++; return }
        if (l.map { it.key } != startOrder) {
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
            if (e.isTxt) {
                val t = withContext(Dispatchers.IO) { Store.readPlain(ctx, e.uri) }
                if (t != null) note = t else toast("Dosya okunamadı")
                return@launch
            }
            val u = withContext(Dispatchers.IO) { Store.readUrl(ctx, e.uri) }
            if (u == null) {
                val t = withContext(Dispatchers.IO) { Store.readText(ctx, e.uri) }
                if (t != null) note = t else toast("Link okunamadı")
            }
            else try { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) } catch (ex: Exception) { toast("Link açılamadı") }
        }
    }
    fun addTxt() {
        val text = linkText.trim()
        if (text.isEmpty()) return
        linkText = ""
        focus.clearFocus()
        scope.launch {
            val ok = withContext(Dispatchers.IO) { Store.addTextFile(ctx, current, text) }
            tick++
            toast(if (ok) "Metin dosyası eklendi" else "Eklenemedi")
        }
    }
    fun addFromText() {
        val text = linkText.trim()
        if (text.isEmpty()) return
        if (text.length > addMax) { toast("$addMax karakteri aşıyor. + simgesine uzun basarak .txt olarak kaydedin"); return }
        linkText = ""
        focus.clearFocus()
        scope.launch {
            val ok = withContext(Dispatchers.IO) { Store.addFromText(ctx, current, text) }
            tick++
            toast(if (ok) "Eklendi" else "Eklenemedi")
        }
    }
    fun startSearch() {
        val q = linkText.trim()
        if (q.isEmpty()) return
        focus.clearFocus()
        selected = emptySet()
        searchJob?.cancel()
        searchQuery = q; hits = null
        searchJob = scope.launch {
            val r = withContext(Dispatchers.IO) { Store.search(ctx, rootUri, q) { isActive } }
            hits = r
        }
    }
    fun exitSearch(clearText: Boolean) {
        searchJob?.cancel()
        if (clearText && linkText.trim() == searchQuery) linkText = ""
        searchQuery = null; hits = null
    }
    fun deleteNow(items: List<Entry>) {
        selected = emptySet()
        run { items.forEach { Store.delete(ctx, it.uri) } }
    }
    fun startRename(e: Entry) { renameText = e.title; renaming = e }
    fun saveRename() {
        val r = rn ?: return
        val n = renameText
        if (n.isBlank()) return
        renaming = null; selected = emptySet()
        focus.clearFocus()
        scope.launch {
            val ok = lock.withLock { withContext(Dispatchers.IO) { Store.rename(ctx, current, r, n) } }
            tick++
            if (!ok) toast("Ad değiştirilemedi (aynı adda öğe olabilir)")
        }
    }
    LaunchedEffect(rn?.key) { if (rn != null) { delay(100); runCatching { renameFocus.requestFocus() } } }
    fun toggle(e: Entry) { selected = if (e.key in selected) selected - e.key else selected + e.key }

    Scaffold(bottomBar = {
        if (rn != null) Surface(tonalElevation = 3.dp) {
            Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = 8.dp, vertical = 6.dp)) {
                OutlinedTextField(
                    renameText, { renameText = it.take(maxChars) },
                    modifier = Modifier.fillMaxWidth().focusRequester(renameFocus),
                    label = { Text(if (rn.isDir) "Klasör adı" else "Yeni ad") },
                    singleLine = false, minLines = 1, maxLines = 4,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    TextButton({ renaming = null }) { Text("İptal") }
                    Spacer(Modifier.weight(1f))
                    Text("${renameText.length}/$maxChars", style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(end = 8.dp))
                    Button({ saveRename() }, enabled = renameText.isNotBlank()) { Text("Kaydet") }
                }
            }
        } else if (!selecting) Surface(tonalElevation = 3.dp) {
            Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp)) {
                OutlinedTextField(
                    linkText, { linkText = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Link veya metin yapıştır (+ uzun bas: .txt)") },
                    singleLine = false, minLines = 2, maxLines = 8,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    val canAdd = linkText.isNotBlank()
                    Box(
                        Modifier.size(48.dp).clip(CircleShape)
                            .combinedClickable(enabled = canAdd, onClick = { addFromText() }, onLongClick = { addTxt() }),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Default.Add, "Ekle (uzun bas: .txt)", tint = LocalContentColor.current.copy(alpha = if (canAdd) 1f else 0.38f)) }
                    IconButton({ startSearch() }, enabled = linkText.isNotBlank()) { Icon(Icons.Default.Search, "Ara") }
                    IconButton({ clipboard.getText()?.text?.let { linkText = it } }) { Icon(Icons.Default.ContentPaste, "Yapıştır") }
                    Spacer(Modifier.weight(1f))
                    Text("${linkText.length}/$addMax", style = MaterialTheme.typography.labelSmall, color = if (linkText.length > addMax) MaterialTheme.colorScheme.error else Color.Unspecified, modifier = Modifier.padding(end = 8.dp))
                }
            }
        }
    }, topBar = {
        if (searchQuery != null) TopAppBar(
            title = {
                Text("“$searchQuery”" + (hits?.let { " · ${it.size} sonuç" } ?: ""), maxLines = 1, overflow = TextOverflow.Ellipsis)
            },
            navigationIcon = { IconButton({ exitSearch(true) }) { Icon(Icons.Default.ArrowBack, "Aramadan çık") } })
        else if (selecting) TopAppBar(
            title = { Text("${selected.size} seçili") },
            navigationIcon = { IconButton({ renaming = null; selected = emptySet() }) { Icon(Icons.Default.Close, "İptal") } },
            actions = {
                if (selected.size > 1) {
                    IconButton({ dialog = "move" }) { Icon(Icons.Default.DriveFileMove, "Taşı") }
                    IconButton({ deleteNow(list.filter { it.key in selected }) }) { Icon(Icons.Default.Delete, "Sil") }
                }
            })
        else TopAppBar(
            title = { Text(if (stack.isEmpty()) "Link Cepte" else stack.last().name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = { if (stack.isNotEmpty()) IconButton({ stack = stack.dropLast(1) }) { Icon(Icons.Default.ArrowBack, "Geri") } },
            actions = {
                IconButton({ dialog = "folder" }) { Icon(Icons.Default.CreateNewFolder, "Klasör") }
                IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, "Menü") }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem({ Text("Klasörü değiştir") }, { menu = false; pickFolder.launch(null) })
                }
            })
    }) { pad ->
        if (searchQuery != null) SearchResults(pad, hits, { open(it) }) { path ->
            exitSearch(true); stack = path
        } else {
        if (loaded != null && list.isEmpty()) Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) {
            Text("Burada henüz bir şey yok. Alttaki alana link veya metin yapıştırın ya da tarayıcıda Paylaş → Link Cepte'yi seçin.")
        }
        LazyColumn(Modifier.padding(pad).fillMaxSize(), state = listState) {
            items(list, key = { it.key }) { e ->
                val sel = e.key in selected
                val dragging = e.key == dragKey
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
                                    selecting -> toggle(e)
                                    e.isDir -> stack = stack + e
                                    else -> open(e)
                                }
                            },
                            onLongClick = { toggle(e) }),
                        colors = ListItemDefaults.colors(containerColor = when {
                            dragging -> MaterialTheme.colorScheme.surfaceVariant
                            sel -> MaterialTheme.colorScheme.secondaryContainer
                            else -> MaterialTheme.colorScheme.surface
                        }),
                        leadingContent = {
                            if (selecting) Checkbox(sel, null)
                            else Icon(if (e.isDir) Icons.Default.Folder else if (e.isTxt) Icons.Default.Description else Icons.Default.Link, null)
                        },
                        headlineContent = { Text(e.title, maxLines = 4, overflow = TextOverflow.Ellipsis) },
                        trailingContent = {
                            if (sel && selected.size == 1) Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton({ startRename(e) }, Modifier.size(40.dp)) { Icon(Icons.Default.Edit, "Adı değiştir") }
                                IconButton({ dialog = "move" }, Modifier.size(40.dp)) { Icon(Icons.Default.DriveFileMove, "Taşı") }
                                IconButton({ deleteNow(listOf(e)) }, Modifier.size(40.dp)) { Icon(Icons.Default.Delete, "Sil") }
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
    }

    note?.let { t ->
        AlertDialog(
            onDismissRequest = { note = null },
            text = { Text(t, modifier = Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) },
            confirmButton = { TextButton({ note = null }) { Text("Kapat") } },
            dismissButton = { TextButton({ clipboard.setText(AnnotatedString(t)); toast("Kopyalandı") }) { Text("Kopyala") } })
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

    if (dialog == "move") {
        val files = list.filter { it.key in selected }
        val exclude = files.filter { it.isDir }.map { it.uri }.toSet()   // klasör kendi içine taşınamaz
        MoveDialog(ctx, rootUri, current, exclude, { dialog = null }) { target ->
            val from = current
            dialog = null; selected = emptySet()
            scope.launch {
                val ok = lock.withLock { withContext(Dispatchers.IO) { files.count { Store.moveEntry(ctx, it, from, target) } } }
                tick++
                toast(if (ok == files.size) "$ok öğe taşındı" else "$ok/${files.size} öğe taşınabildi")
            }
        }
    }
}

@Composable
fun MoveDialog(ctx: android.content.Context, root: Uri, current: Uri, exclude: Set<Uri>, onDismiss: () -> Unit, onPick: (Uri) -> Unit) {
    var stack by remember { mutableStateOf(listOf<Entry>()) }
    val dir = stack.lastOrNull()?.uri ?: root
    val scope = rememberCoroutineScope()
    var creating by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var folders by remember(dir) { mutableStateOf(emptyList<Entry>()) }
    LaunchedEffect(dir) { folders = withContext(Dispatchers.IO) { Store.list(ctx, dir).filter { it.isDir && it.uri !in exclude } } }
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
                                val all = withContext(Dispatchers.IO) { Store.addFolder(ctx, dir, n); Store.list(ctx, dir).filter { it.isDir && it.uri !in exclude } }
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


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchResults(pad: PaddingValues, hits: List<Hit>?, onOpen: (Entry) -> Unit, onGoto: (List<Entry>) -> Unit) {
    when {
        hits == null -> Box(Modifier.padding(pad).fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
        hits.isEmpty() -> Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) { Text("Sonuç bulunamadı.") }
        else -> LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            items(hits, key = { it.entry.key }) { h ->
                ListItem(
                    modifier = Modifier.clickable { onOpen(h.entry) },
                    overlineContent = { Text(if (h.path.isEmpty()) "Ana liste" else h.path.joinToString(" › ") { it.name }, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    leadingContent = { Icon(if (h.isNote || h.entry.isTxt) Icons.Default.Description else Icons.Default.Link, null) },
                    headlineContent = { Text(h.entry.title, maxLines = 4, overflow = TextOverflow.Ellipsis) },
                    supportingContent = { if (h.detail.isNotBlank()) Text(h.detail, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                    trailingContent = { IconButton({ onGoto(h.path) }) { Icon(Icons.Default.FolderOpen, "Klasöre git") } })
                HorizontalDivider()
            }
        }
    }
}
