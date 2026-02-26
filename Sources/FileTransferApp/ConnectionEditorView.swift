import SwiftUI

struct ConnectionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Connection
    let onSave: (Connection) -> Void

    init(connection: Connection?, onSave: @escaping (Connection) -> Void) {
        _draft = State(initialValue: connection ?? Connection(name: "", host: "", username: ""))
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)

            TextField("Name", text: $draft.name)
            TextField("Host", text: $draft.host)
            TextField("Username", text: $draft.username)

            HStack {
                Text("Port")
                Stepper(value: $draft.port, in: 1...65535) {
                    Text("\(draft.port)")
                        .frame(width: 60, alignment: .leading)
                }
            }

            Picker("Auth", selection: authBinding) {
                Text("Password").tag("password")
                Text("Key file").tag("key")
            }
            .pickerStyle(.segmented)

            if case .key(let path) = draft.authMethod {
                TextField("Private key path", text: Binding(
                    get: { path },
                    set: { draft.authMethod = .key(path: $0) }
                ))
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.isEmpty || draft.host.isEmpty || draft.username.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 260)
    }

    private var authBinding: Binding<String> {
        Binding(
            get: {
                switch draft.authMethod {
                case .password:
                    return "password"
                case .key:
                    return "key"
                }
            },
            set: { value in
                if value == "key" {
                    draft.authMethod = .key(path: "")
                } else {
                    draft.authMethod = .password
                }
            }
        )
    }
}
