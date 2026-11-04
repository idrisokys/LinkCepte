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
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.TextRange
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
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
    var editMode by remember { mutableStateOf(false) }          // üstteki düzenle tuşu
    var selected by remember { mutableStateOf(setOf<String>()) } // düzenleme modunda işaretlenen öğeler
    var moving by remember { mutableStateOf<List<Entry>>(emptyList()) }   // taşınacak öğeler
    var dialog by remember { mutableStateOf<String?>(null) }
    var renameText by remember { mutableStateOf("") }
    var menu by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf<String?>(null) }
    var txtDoc by remember { mutableStateOf<Pair<Entry, String>?>(null) }   // tam ekranda açık .txt (öğe, içerik)
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
            if (Store.setRoot(ctx, uri)) { root = Store.root(ctx); stack = emptyList(); tick++ }
            else toast(L("Bu klasöre yazılamıyor, başka bir klasör seçin", "Cannot write to this folder, choose another one"))
        }
    }

    val rootUri = root
    if (rootUri == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Link Cepte", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(12.dp))
            Text(L("Linklerin kaydedileceği klasörü seçin.", "Choose the folder where links will be saved."))
            Spacer(Modifier.height(16.dp))
            Button(onClick = { pickFolder.launch(null) }) { Text(L("Klasör seç", "Choose folder")) }
        }
        return
    }

    val current = stack.lastOrNull()?.uri ?: rootUri
    var loaded by remember(current) { mutableStateOf<List<Entry>?>(null) }
    LaunchedEffect(current, tick, resume) { loaded = withContext(Dispatchers.IO) { Store.list(ctx, current) } }
    val list = loaded ?: emptyList()
    // Düzenleme modunda tam bir öğe seçiliyse adı alttaki geniş alanda değiştirilir
    val rn: Entry? = if (editMode && selected.size == 1) list.firstOrNull { it.key in selected } else null
    LaunchedEffect(rn?.key) { renameText = rn?.title ?: "" }
    LaunchedEffect(current) { selected = emptySet() }   // klasör değişince işaretler temizlenir
    BackHandler(searchQuery != null || editMode || stack.isNotEmpty()) {
        when {
            searchQuery != null -> { searchJob?.cancel(); searchQuery = null; hits = null }
            editMode -> { editMode = false; selected = emptySet() }
            else -> stack = stack.dropLast(1)
        }
    }

    // ---- Sıralama: düzenleme modunda seçili satır ok tuşlarıyla yukarı/aşağı taşınır ----
    val listState = rememberLazyListState()
    val currentDir by rememberUpdatedState(current)

    // mode: -1 bir yukarı, 1 bir aşağı, -2 başa al, 2 sona al (seçili tüm öğeler için)
    fun moveSelected(mode: Int) {
        val l = loaded ?: return
        val sel = selected
        if (sel.isEmpty()) return
        val m = l.toMutableList()
        when (mode) {
            -1 -> for (i in 1 until m.size) if (m[i].key in sel && m[i - 1].key !in sel) { val t = m[i]; m[i] = m[i - 1]; m[i - 1] = t }
            1 -> for (i in m.size - 2 downTo 0) if (m[i].key in sel && m[i + 1].key !in sel) { val t = m[i]; m[i] = m[i + 1]; m[i + 1] = t }
            -2 -> { val a = m.filter { it.key in sel }; val b = m.filter { it.key !in sel }; m.clear(); m.addAll(a + b) }
            2 -> { val a = m.filter { it.key in sel }; val b = m.filter { it.key !in sel }; m.clear(); m.addAll(b + a) }
        }
        if (m.map { it.key } == l.map { it.key }) return
        loaded = m
        val names = m.map { it.name }
        val dir = currentDir
        run(reload = false) { Store.saveOrder(ctx, dir, names) }
        // Taşınan öğe ekran dışına çıktıysa görünür kıl
        val idx = if (mode < 0) m.indexOfFirst { it.key in sel } else m.indexOfLast { it.key in sel }
        val key = m[idx].key
        scope.launch {
            delay(50)
            val info = listState.layoutInfo
            val it = info.visibleItemsInfo.firstOrNull { x -> x.key == key }
            if (it == null || it.offset < info.viewportStartOffset || it.offset + it.size > info.viewportEndOffset)
                listState.animateScrollToItem((idx - 1).coerceAtLeast(0))
        }
    }
    // Seçililer zaten en üstte/en altta toplanmışsa ilgili düğme pasif olur
    val selIdx = list.indices.filter { list[it].key in selected }
    val canUp = selIdx.withIndex().any { (n, i) -> i != n }
    val canDown = selIdx.withIndex().any { (n, i) -> i != list.size - selIdx.size + n }
    fun open(e: Entry) {
        scope.launch {
            if (e.isTxt) {
                val t = withContext(Dispatchers.IO) { Store.readPlain(ctx, e.uri) }
                if (t != null) txtDoc = e to t else toast(L("Dosya okunamadı", "Could not read file"))
                return@launch
            }
            val (u, t) = withContext(Dispatchers.IO) { Store.readLink(ctx, e.uri) }
            if (u == null) {
                if (t != null) note = t else toast(L("Link okunamadı", "Could not read link"))
            }
            else try { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) } catch (ex: Exception) { toast(L("Link açılamadı", "Could not open link")) }
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
            toast(if (ok) L("Metin dosyası eklendi", "Text file added") else L("Eklenemedi", "Could not add"))
        }
    }
    fun addFromText() {
        val text = linkText.trim()
        if (text.isEmpty()) return
        if (text.length > addMax) { toast(L("$addMax karakteri aşıyor. + simgesine uzun basarak .txt olarak kaydedin", "Over $addMax characters. Long-press + to save as .txt")); return }
        linkText = ""
        focus.clearFocus()
        scope.launch {
            val ok = withContext(Dispatchers.IO) { Store.addFromText(ctx, current, text) }
            tick++
            toast(if (ok) L("Eklendi", "Added") else L("Eklenemedi", "Could not add"))
        }
    }
    fun startSearch() {
        val q = linkText.trim()
        if (q.isEmpty()) return
        focus.clearFocus()
        editMode = false; selected = emptySet()
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
    fun saveRename() {
        val r = rn ?: return
        val n = renameText
        if (n.isBlank()) return
        selected = emptySet()
        focus.clearFocus()
        scope.launch {
            val ok = lock.withLock { withContext(Dispatchers.IO) { Store.rename(ctx, current, r, n) } }
            tick++
            if (!ok) toast(L("Ad değiştirilemedi (aynı adda öğe olabilir)", "Could not rename (an item with that name may exist)"))
        }
    }

    Scaffold(bottomBar = {
        if (rn != null) Surface(tonalElevation = 3.dp) {
            Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = 8.dp, vertical = 6.dp)) {
                OutlinedTextField(
                    renameText, { renameText = it.take(maxChars) },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(if (rn.isDir) L("Klasör adı", "Folder name") else L("Ad", "Name")) },
                    singleLine = false, minLines = 1, maxLines = 4,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    IconButton({ clipboard.getText()?.text?.let { renameText = it.take(maxChars) } }) { Icon(Icons.Default.ContentPaste, L("Yapıştır", "Paste")) }
                    IconButton({ saveRename() }, enabled = renameText.isNotBlank()) {
                        Icon(Icons.Default.Save, L("Kaydet", "Save"),
                            tint = if (renameText.isNotBlank()) MaterialTheme.colorScheme.primary else LocalContentColor.current.copy(alpha = 0.38f))
                    }
                    MoveButtons(canUp, canDown) { moveSelected(it) }
                    Spacer(Modifier.weight(1f))
                    Text("${renameText.length}/$maxChars", style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(end = 8.dp))
                }
            }
        } else if (editMode && selected.size > 1) Surface(tonalElevation = 3.dp) {
            Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                MoveButtons(canUp, canDown) { moveSelected(it) }
                Spacer(Modifier.weight(1f))
                Text(L("${selected.size} seçili", "${selected.size} selected"), style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(end = 8.dp))
            }
        } else Surface(tonalElevation = 3.dp) {
            Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp)) {
                OutlinedTextField(
                    linkText, { linkText = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text(L("Link veya metin yapıştır (+ uzun bas: .txt)", "Paste a link or text (long-press +: .txt)")) },
                    singleLine = false, minLines = 2, maxLines = 8,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    val canAdd = linkText.isNotBlank()
                    Box(
                        Modifier.size(48.dp).clip(CircleShape)
                            .combinedClickable(enabled = canAdd, onClick = { addFromText() }, onLongClick = { addTxt() }),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Default.Add, L("Ekle (uzun bas: .txt)", "Add (long-press: .txt)"), tint = LocalContentColor.current.copy(alpha = if (canAdd) 1f else 0.38f)) }
                    IconButton({ startSearch() }, enabled = linkText.isNotBlank()) { Icon(Icons.Default.Search, L("Ara", "Search")) }
                    IconButton({ clipboard.getText()?.text?.let { linkText = it } }) { Icon(Icons.Default.ContentPaste, L("Yapıştır", "Paste")) }
                    Spacer(Modifier.weight(1f))
                    Text("${linkText.length}/$addMax", style = MaterialTheme.typography.labelSmall, color = if (linkText.length > addMax) MaterialTheme.colorScheme.error else Color.Unspecified, modifier = Modifier.padding(end = 8.dp))
                }
            }
        }
    }, topBar = {
        if (searchQuery != null) TopAppBar(
            title = {
                Text("“$searchQuery”" + (hits?.let { " · ${it.size} " + L("sonuç", "results") } ?: ""), maxLines = 1, overflow = TextOverflow.Ellipsis)
            },
            navigationIcon = { IconButton({ exitSearch(true) }) { Icon(Icons.Default.ArrowBack, L("Aramadan çık", "Exit search")) } })
        else TopAppBar(
            title = {
                Text(
                    if (editMode && selected.isNotEmpty()) L("${selected.size} seçili", "${selected.size} selected") else if (stack.isEmpty()) "Link Cepte" else stack.last().name,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            },
            navigationIcon = { if (stack.isNotEmpty()) IconButton({ stack = stack.dropLast(1) }) { Icon(Icons.Default.ArrowBack, L("Geri", "Back")) } },
            actions = {
                if (editMode && selected.isNotEmpty()) {
                    IconButton({ moving = list.filter { it.key in selected }; dialog = "move" }) { Icon(Icons.Default.DriveFileMove, L("Taşı", "Move")) }
                    IconButton({ deleteNow(list.filter { it.key in selected }) }) { Icon(Icons.Default.Delete, L("Sil", "Delete")) }
                }
                IconButton({ dialog = "folder" }) { Icon(Icons.Default.CreateNewFolder, L("Klasör", "Folder")) }
                IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, L("Menü", "Menu")) }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem({ Text(L("Klasörü değiştir", "Change folder")) }, { menu = false; pickFolder.launch(null) })
                }
                // Düzenle tuşu: satırlarda seçim kutusunu açar/kapatır; tek öğe seçilince adı altta değiştirilir, ok tuşlarıyla sırası değiştirilir
                IconButton({ editMode = !editMode; selected = emptySet() }) {
                    Icon(if (editMode) Icons.Default.Done else Icons.Default.Edit, if (editMode) L("Düzenlemeyi bitir", "Done editing") else L("Düzenle", "Edit"))
                }
                // En sağdaki yenile tuşu: kayıtlı klasörü yeniden tarar (başka cihazdan eşitlenen değişiklikleri getirir)
                IconButton({ tick++; toast(L("Yenilendi", "Refreshed")) }) { Icon(Icons.Default.Refresh, L("Yenile", "Refresh")) }
            })
    }) { pad ->
        if (searchQuery != null) SearchResults(pad, hits, { open(it) }) { path ->
            exitSearch(true); stack = path
        } else {
        if (loaded != null && list.isEmpty()) Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) {
            Text(L("Burada henüz bir şey yok. Alttaki alana link veya metin yapıştırın ya da tarayıcıda Paylaş → Link Cepte'yi seçin.", "Nothing here yet. Paste a link or text in the field below, or choose Share → Link Cepte in your browser."))
        }
        LazyColumn(Modifier.padding(pad).fillMaxSize(), state = listState) {
            items(list, key = { it.key }) { e ->
                val sel = e.key in selected
                Column(Modifier.animateItemPlacement()) {
                    ListItem(
                        modifier = Modifier.clickable {
                            when {
                                editMode -> selected = if (sel) selected - e.key else selected + e.key
                                e.isDir -> stack = stack + e
                                else -> open(e)
                            }
                        },
                        colors = ListItemDefaults.colors(containerColor = when {
                            sel -> MaterialTheme.colorScheme.secondaryContainer
                            else -> MaterialTheme.colorScheme.surface
                        }),
                        leadingContent = {
                            if (editMode) Checkbox(sel, { selected = if (sel) selected - e.key else selected + e.key })
                            else Icon(if (e.isDir) Icons.Default.Folder else if (e.isTxt) Icons.Default.Description else Icons.Default.Link, null)
                        },
                        headlineContent = { Text(e.title, maxLines = 4, overflow = TextOverflow.Ellipsis) })
                    HorizontalDivider()
                }
            }
        }
        }
    }

    txtDoc?.let { (e, text) ->
        key(e.key) {
            TxtScreen(
                title = e.title, initial = text,
                onSave = { t -> lock.withLock { withContext(Dispatchers.IO) { Store.writePlain(ctx, e.uri, t) } } },
                onCopy = { t -> clipboard.setText(AnnotatedString(t)); toast(L("Kopyalandı", "Copied")) },
                onClose = { txtDoc = null })
        }
    }

    note?.let { t ->
        AlertDialog(
            onDismissRequest = { note = null },
            text = { Text(t, modifier = Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) },
            confirmButton = { TextButton({ note = null }) { Text(L("Kapat", "Close")) } },
            dismissButton = { TextButton({ clipboard.setText(AnnotatedString(t)); toast(L("Kopyalandı", "Copied")) }) { Text(L("Kopyala", "Copy")) } })
    }

    if (dialog == "folder") {
        var title by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text(L("Yeni klasör", "New folder")) },
            text = { OutlinedTextField(title, { title = it }, label = { Text(L("Klasör adı", "Folder name")) }, singleLine = true) },
            confirmButton = { TextButton({ val n = title; dialog = null; run { Store.addFolder(ctx, current, n) } }, enabled = title.isNotBlank()) { Text(L("Oluştur", "Create")) } },
            dismissButton = { TextButton({ dialog = null }) { Text(L("İptal", "Cancel")) } })
    }

    if (dialog == "move") {
        val files = moving
        val exclude = files.filter { it.isDir }.map { it.uri }.toSet()   // klasör kendi içine taşınamaz
        MoveDialog(ctx, rootUri, current, exclude, { dialog = null }) { target ->
            val from = current
            dialog = null; moving = emptyList(); selected = emptySet()
            scope.launch {
                val ok = lock.withLock { withContext(Dispatchers.IO) { files.count { Store.moveEntry(ctx, it, from, target) } } }
                tick++
                toast(if (ok == files.size) L("$ok öğe taşındı", "$ok items moved") else L("$ok/${files.size} öğe taşınabildi", "$ok/${files.size} items could be moved"))
            }
        }
    }
}

/** Düzenleme modunda seçili öğeler için: başa al, yukarı, aşağı, sona al. */
@Composable
fun MoveButtons(canUp: Boolean, canDown: Boolean, onMove: (Int) -> Unit) {
    IconButton({ onMove(-2) }, enabled = canUp) { Icon(Icons.Default.VerticalAlignTop, L("Başa al", "Move to top")) }
    IconButton({ onMove(-1) }, enabled = canUp) { Icon(Icons.Default.KeyboardArrowUp, L("Yukarı taşı", "Move up")) }
    IconButton({ onMove(1) }, enabled = canDown) { Icon(Icons.Default.KeyboardArrowDown, L("Aşağı taşı", "Move down")) }
    IconButton({ onMove(2) }, enabled = canDown) { Icon(Icons.Default.VerticalAlignBottom, L("Sona al", "Move to bottom")) }
}

/** .txt dosyasını tam ekranda gösterir; sağ üstteki kalemle düzenlenir, kaydet ikonuyla kaydedilip okuma görünümüne dönülür. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TxtScreen(
    title: String, initial: String,
    onSave: suspend (String) -> Boolean,
    onCopy: (String) -> Unit,
    onClose: () -> Unit
) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var saved by remember { mutableStateOf(initial) }                 // dosyadaki son hâl
    var editing by remember { mutableStateOf(false) }
    var value by remember { mutableStateOf(TextFieldValue(initial)) }
    var saving by remember { mutableStateOf(false) }
    var askDiscard by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    val dirty = editing && value.text != saved

    fun startEdit() { value = TextFieldValue(saved, TextRange(saved.length)); editing = true }
    fun save() {
        if (saving) return
        saving = true
        val t = value.text
        scope.launch {
            val ok = onSave(t)
            saving = false
            if (ok) { saved = t; editing = false; askDiscard = false }
            else Toast.makeText(ctx, L("Kaydedilemedi", "Could not save"), Toast.LENGTH_SHORT).show()
        }
    }
    fun back() {
        when {
            dirty -> askDiscard = true
            editing -> editing = false
            else -> onClose()
        }
    }
    LaunchedEffect(editing) { if (editing) { delay(100); runCatching { focus.requestFocus() } } }

    Dialog(onDismissRequest = { back() }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize()) {
            Scaffold(topBar = {
                TopAppBar(
                    title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    navigationIcon = { IconButton({ back() }) { Icon(Icons.Default.ArrowBack, L("Geri", "Back")) } },
                    actions = {
                        if (editing) {
                            IconButton({ save() }, enabled = !saving) {
                                Icon(Icons.Default.Save, L("Kaydet", "Save"), tint = MaterialTheme.colorScheme.primary)
                            }
                        } else {
                            IconButton({ onCopy(saved) }) { Icon(Icons.Default.ContentCopy, L("Kopyala", "Copy")) }
                            IconButton({ startEdit() }) { Icon(Icons.Default.Edit, L("Düzenle", "Edit")) }
                        }
                    })
            }) { pad ->
                if (editing) {
                    TextField(
                        value, { value = it },
                        modifier = Modifier.padding(pad).fillMaxSize().imePadding().focusRequester(focus),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default))
                } else {
                    SelectionContainer {
                        Text(saved, Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp))
                    }
                }
            }
        }
    }

    if (askDiscard) AlertDialog(
        onDismissRequest = { askDiscard = false },
        title = { Text(L("Kaydedilmemiş değişiklikler var", "Unsaved changes")) },
        text = { Text(L("Değişiklikleri kaydetmek ister misiniz?", "Do you want to save your changes?")) },
        confirmButton = { TextButton({ save() }) { Text(L("Kaydet", "Save")) } },
        dismissButton = {
            Row {
                TextButton({ askDiscard = false }) { Text(L("İptal", "Cancel")) }
                TextButton({ askDiscard = false; editing = false }) { Text(L("Kaydetme", "Discard")) }
            }
        })
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
        title = { Text(L("Taşı", "Move") + ": " + (stack.lastOrNull()?.name ?: L("Ana liste", "Main list"))) },
        text = {
            LazyColumn(Modifier.heightIn(max = 320.dp)) {
                if (stack.isNotEmpty()) item {
                    ListItem(modifier = Modifier.clickable { stack = stack.dropLast(1) },
                        leadingContent = { Icon(Icons.Default.ArrowBack, null) }, headlineContent = { Text(L("Üst klasör", "Parent folder")) })
                }
                item {
                    if (!creating) ListItem(modifier = Modifier.clickable { creating = true },
                        leadingContent = { Icon(Icons.Default.CreateNewFolder, null) }, headlineContent = { Text(L("Yeni klasör oluştur", "Create new folder")) })
                    else Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(newName, { newName = it }, label = { Text(L("Klasör adı", "Folder name")) }, singleLine = true, modifier = Modifier.weight(1f))
                        TextButton(enabled = newName.isNotBlank(), onClick = {
                            val n = newName
                            val before = folders.map { it.uri }.toSet()
                            creating = false; newName = ""
                            scope.launch {
                                val all = withContext(Dispatchers.IO) { Store.addFolder(ctx, dir, n); Store.list(ctx, dir).filter { it.isDir && it.uri !in exclude } }
                                folders = all
                                all.firstOrNull { it.uri !in before }?.let { stack = stack + it }
                            }
                        }) { Text(L("Oluştur", "Create")) }
                    }
                }
                items(folders, key = { it.key }) { f ->
                    ListItem(modifier = Modifier.clickable { stack = stack + f },
                        leadingContent = { Icon(Icons.Default.Folder, null) }, headlineContent = { Text(f.name, maxLines = 1, overflow = TextOverflow.Ellipsis) })
                }
            }
        },
        confirmButton = { TextButton({ onPick(dir) }, enabled = dir != current) { Text(L("Buraya taşı", "Move here")) } },
        dismissButton = { TextButton(onDismiss) { Text(L("İptal", "Cancel")) } })
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchResults(pad: PaddingValues, hits: List<Hit>?, onOpen: (Entry) -> Unit, onGoto: (List<Entry>) -> Unit) {
    when {
        hits == null -> Box(Modifier.padding(pad).fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
        hits.isEmpty() -> Box(Modifier.padding(pad).fillMaxSize().padding(32.dp), Alignment.Center) { Text(L("Sonuç bulunamadı.", "No results found.")) }
        else -> LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            items(hits, key = { it.entry.key }) { h ->
                ListItem(
                    modifier = Modifier.clickable { onOpen(h.entry) },
                    overlineContent = { Text(if (h.path.isEmpty()) L("Ana liste", "Main list") else h.path.joinToString(" › ") { it.name }, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    leadingContent = { Icon(if (h.isNote || h.entry.isTxt) Icons.Default.Description else Icons.Default.Link, null) },
                    headlineContent = { Text(h.entry.title, maxLines = 4, overflow = TextOverflow.Ellipsis) },
                    supportingContent = { if (h.detail.isNotBlank()) Text(h.detail, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                    trailingContent = { IconButton({ onGoto(h.path) }) { Icon(Icons.Default.FolderOpen, L("Klasöre git", "Go to folder")) } })
                HorizontalDivider()
            }
        }
    }
}
