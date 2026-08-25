## Records every dispatched command and optionally persists the log to disk.
##
## Obtain the singleton instance via [method QTICommand.get_history]. Enable persistence with [method QTICommand.set_history_persistence].
class_name QTIHistory
extends RefCounted

## A single history entry.
class Entry:
    ## Stable string key identifying the invoker (object instance ID or raw value).
    var invoker_key: String
    ## The raw input string that was dispatched.
    var raw_input: String
    ## Unix timestamp (seconds) of when the command was dispatched.
    var timestamp_unix: int
    ## Whether the command succeeded.
    var success: bool

    func _init(p_invoker_key: String, p_raw_input: String, p_timestamp_unix: int, p_success: bool) -> void:
        invoker_key = p_invoker_key
        raw_input = p_raw_input
        timestamp_unix = p_timestamp_unix
        success = p_success

## Maximum entries retained in memory and on disk when persistence is not configured.
const DEFAULT_MAX_ENTRIES := 200
## Path used when disk persistence is enabled.
const SAVE_PATH := "user://qti_history.dat"

var _entries: Array[Entry] = []
var _persist_enabled: bool = false
var _max_entries: int = DEFAULT_MAX_ENTRIES
var _exclude_patterns: Array = []

## Enables or disables disk persistence.
## [param opts] may contain:
## [br]- [code]max_entries[/code] ([int]) — cap on stored entries (default [constant DEFAULT_MAX_ENTRIES]).
## [br]- [code]exclude_patterns[/code] ([Array]) — substring or regex patterns; matching inputs are neither saved nor loaded.
func set_persistence(enabled: bool, opts: Dictionary = {}) -> void:
    _persist_enabled = enabled
    _max_entries = opts.get("max_entries", DEFAULT_MAX_ENTRIES)
    _exclude_patterns = opts.get("exclude_patterns", [])
    if enabled:
        _load()

## Appends an entry for [param raw_input] dispatched by [param invoker_key]. Trims the oldest entry when [member _max_entries] is exceeded, then auto-saves if persistence is enabled.
func record(invoker_key: String, raw_input: String, success: bool) -> void:
    if raw_input == "":
        return
    _entries.append(Entry.new(invoker_key, raw_input, int(Time.get_unix_time_from_system()), success))
    while _entries.size() > _max_entries:
        _entries.pop_front()
    if _persist_enabled:
        _save()

## Returns the [param n] most recent entries, optionally filtered to a single [param invoker_key]. Pass [code]""[/code] as [param invoker_key] to include all invokers.
func get_recent(n: int = 20, invoker_key: String = "") -> Array[Entry]:
    var filtered: Array[Entry] = _entries
    if invoker_key != "":
        filtered = []
        for e in _entries:
            if e.invoker_key == invoker_key:
                filtered.append(e)
    var start := maxi(0, filtered.size() - n)
    return filtered.slice(start)

## Clears all in-memory entries and overwrites the persistence file if enabled.
func clear() -> void:
    _entries.clear()
    if _persist_enabled:
        _save()

func _is_excluded(raw_input: String) -> bool:
    var lower_input := raw_input.to_lower()
    for pattern in _exclude_patterns:
        var p := String(pattern)
        var looks_like_regex := p.begins_with("^") or p.find("\\") != -1 or p.find("[") != -1 or p.find("(") != -1
        if looks_like_regex:
            var re := RegEx.new()
            if re.compile(p) == OK and re.search(raw_input) != null:
                return true
        elif lower_input.find(p.to_lower()) != -1:
            return true
    return false

func _save() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("QTICommand: failed to open history file for writing: %s" % SAVE_PATH)
        return
    var serializable := []
    for e in _entries:
        if _is_excluded(e.raw_input):
            continue
        serializable.append({
            "invoker_key": e.invoker_key,
            "raw_input": e.raw_input,
            "timestamp_unix": e.timestamp_unix,
            "success": e.success,
        })
    file.store_string(JSON.stringify(serializable))
    file.close()

func _load() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var text := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(text)
    if not (parsed is Array):
        return
    _entries.clear()
    for d in parsed:
        if d is Dictionary:
            _entries.append(Entry.new(
                d.get("invoker_key", ""),
                d.get("raw_input", ""),
                int(d.get("timestamp_unix", 0)),
                d.get("success", false)
            ))
