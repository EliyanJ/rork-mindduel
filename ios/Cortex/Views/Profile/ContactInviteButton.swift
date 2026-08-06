import Contacts
import ContactsUI
import MessageUI
import SwiftUI

/// Lets the player pick someone from their address book and invite them to
/// Minduel by text message (their friend code is included when signed in).
/// Two system pickers are involved: the native contact picker (asks for
/// Contacts permission the first time) and the native message composer
/// (no extra permission — it's the same sheet Messages itself uses).
struct ContactInviteButton: View {
    @Environment(OnlineModel.self) private var online
    @State private var isContactPickerPresented = false
    @State private var isMessageComposePresented = false
    @State private var isShareSheetPresented = false
    @State private var pendingRecipient: String?
    @State private var contactsError: String?

    private var inviteText: String {
        let base = "Viens jouer avec moi sur Minduel, l'appli de duels de culture générale ! 🧠"
        let link = "https://apps.apple.com/app/id6788570245"
        if let code = online.profile?.friendCode {
            return "\(base) Ajoute-moi avec mon code ami : \(code)\n\(link)"
        }
        return "\(base)\n\(link)"
    }

    var body: some View {
        Button {
            Haptics.tap()
            isContactPickerPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 15, weight: .heavy))
                Text("Inviter un contact")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.primary.opacity(0.12)))
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPickerRepresentable { phoneNumber in
                isContactPickerPresented = false
                guard let phoneNumber else { return }
                pendingRecipient = phoneNumber
                if MFMessageComposeViewController.canSendText() {
                    isMessageComposePresented = true
                } else {
                    isShareSheetPresented = true
                }
            } onDenied: {
                isContactPickerPresented = false
                contactsError = "Autorise l'accès aux contacts dans Réglages pour inviter tes amis."
            }
        }
        .sheet(isPresented: $isMessageComposePresented) {
            MessageComposeRepresentable(recipient: pendingRecipient, body: inviteText)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheetRepresentable(items: [inviteText])
        }
        .alert("Contacts indisponibles", isPresented: Binding(
            get: { contactsError != nil },
            set: { if !$0 { contactsError = nil } }
        )) {
            Button("OK") { contactsError = nil }
        } message: {
            Text(contactsError ?? "")
        }
    }
}

/// Wraps `CNContactPickerViewController`, filtered to contacts that have at
/// least one phone number since the invite is sent by text message.
private struct ContactPickerRepresentable: UIViewControllerRepresentable {
    /// Called with the selected contact's first phone number, or `nil` if
    /// the picker was dismissed without a selection.
    let onPicked: (String?) -> Void
    let onDenied: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked, onDenied: onDenied) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPicked: (String?) -> Void
        let onDenied: () -> Void

        init(onPicked: @escaping (String?) -> Void, onDenied: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onDenied = onDenied
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let phoneNumber = contact.phoneNumbers.first?.value.stringValue
            onPicked(phoneNumber)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPicked(nil)
        }
    }
}

/// Wraps `MFMessageComposeViewController` to send the invite as a normal
/// text message, prefilled but editable — the player always sends it
/// themselves, nothing is sent automatically.
private struct MessageComposeRepresentable: UIViewControllerRepresentable {
    let recipient: String?
    let body: String

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipient.map { [$0] }
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        nonisolated func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }
    }
}

/// Fallback for devices that can't send text messages (e.g. iPod-class
/// devices without a phone number) — the system share sheet lets the
/// player forward the invite through any app they have installed.
private struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContactInviteButton()
        .environment(OnlineModel(auth: AuthManager()))
        .padding()
}
