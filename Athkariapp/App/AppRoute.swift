import Foundation

enum SessionLaunchAction: String, Equatable {
    case none
    case next
}

enum AppRoute: Equatable {
    case home
    case session(SlotKey, action: SessionLaunchAction = .none)

    static func from(url: URL) -> AppRoute? {
        guard let scheme = url.scheme?.lowercased(), scheme == "athkari" else {
            return nil
        }

        let target: String
        if let host = url.host, !host.isEmpty {
            target = host.lowercased()
        } else {
            target = url.path
                .split(separator: "/")
                .first?
                .lowercased() ?? ""
        }

        switch target {
        case "home":
            return .home
        case "session":
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let slotValue = components.queryItems?.first(where: { $0.name == "slot" })?.value,
                let slot = SlotKey(rawValue: slotValue)
            else {
                return nil
            }

            let actionValue = components.queryItems?.first(where: { $0.name == "action" })?.value?.lowercased()
            let action: SessionLaunchAction
            if actionValue == SessionLaunchAction.next.rawValue {
                action = .next
            } else {
                action = .none
            }

            return .session(slot, action: action)
        default:
            return nil
        }
    }
}
