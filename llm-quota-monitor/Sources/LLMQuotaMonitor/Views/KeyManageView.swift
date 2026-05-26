import SwiftUI

public struct KeyManageView: View {
    public let service: ModelService

    @State private var newName = ""
    @State private var newKey = ""
    @State private var errorMessage: String?
    @State private var editingKeyID: UUID?
    @State private var editingName = ""

    public init(service: ModelService) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("管理 API Key")
                .font(.headline)
                .padding()

            Divider()

            // Key List
            if service.keys.isEmpty {
                Spacer()
                Text("还没有添加 Key")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(Array(service.keys.enumerated()), id: \.element.id) { index, entry in
                        keyRow(for: entry, at: index)
                    }
                    .onDelete(perform: deleteKeys)
                }
            }

            Divider()

            // Add Key Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("名称", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    TextField("API Key", text: $newKey)
                        .textFieldStyle(.roundedBorder)

                    Button("添加") {
                        addKey()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    // MARK: - Key Row

    @ViewBuilder
    private func keyRow(for entry: APIKeyEntry, at index: Int) -> some View {
        if editingKeyID == entry.id {
            HStack {
                TextField("新名称", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commitRename(for: entry, at: index)
                    }

                Button("保存") {
                    commitRename(for: entry, at: index)
                }
                .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("取消") {
                    editingKeyID = nil
                    editingName = ""
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.name)
                        .fontWeight(.medium)
                    Text(entry.maskedKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    editingKeyID = entry.id
                    editingName = entry.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func addKey() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        do {
            try service.addKey(name: trimmedName, key: trimmedKey)
            newName = ""
            newKey = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKeys(at offsets: IndexSet) {
        for offset in offsets.sorted().reversed() {
            do {
                try service.deleteKey(at: offset)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func commitRename(for entry: APIKeyEntry, at index: Int) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try service.renameKey(at: index, newName: trimmed)
            editingKeyID = nil
            editingName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
