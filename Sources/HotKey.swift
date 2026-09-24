import Carbon.HIToolbox

/// 全局快捷键，基于 Carbon RegisterEventHotKey。
/// 默认在 AppDelegate 中注册 ⌥V；如需改成其他组合，
/// 传不同的 keyCode / modifiers 即可（cmdKey / optionKey / shiftKey / controlKey）。
final class HotKey {
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let action: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.action()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4942) /* 'CLIB' */, id: 1)
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                                 GetApplicationEventTarget(), 0, &ref)
        guard registerStatus == noErr else { return nil }
        hotKeyRef = ref
    }
}
