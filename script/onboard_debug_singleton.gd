extends Node

# Singleton responsible for collecting onboard debug messages so UI scenes
# can read them when displayed. This node should be autoloaded.

signal message_appended(priority: int, content: String, sender: String)

var messages: Array = []

func _ready() -> void:
    # Connect to the global SignalBus if present and collect messages
    var sb = get_node_or_null("/root/SignalBus")
    if sb:
        var cb = Callable(self, "_on_onboard_debug_info")
        if not sb.is_connected("onboard_debug_info", cb):
            sb.connect("onboard_debug_info", cb)
            print("OnboardDebugSingleton: connected to SignalBus.onboard_debug_info")
    else:
        print("OnboardDebugSingleton: SignalBus not found; will not receive onboard debug messages")

func _on_onboard_debug_info(priority: int, content: String, sender: String) -> void:
    var entry = {
        "priority": int(priority),
        "content": str(content),
        "sender": str(sender)
    }
    messages.append(entry)
    # Notify any open UI to display the new entry
    message_appended.emit(entry.priority, entry.content, entry.sender)

func get_messages() -> Array:
    # Return a copy so callers don't mutate the internal array accidentally
    return messages.duplicate(true)

func clear_messages() -> void:
    messages.clear()
