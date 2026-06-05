import SwiftUI

public struct KeyManageView: View {
    public let service: ModelService

    @State private var newName = ""
    @State private var newKey = ""
    @State private var newProvider: Provider = .zhiPu
    @State private var errorMessage: String?
    @State private var editingKeyID: UUID?
    @State private var editingName = ""
    @State private var editingKeyValue = ""
    @State private var editingProvider: Provider = .zhiPu
    @State private var keyToDelete: IndexSet?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteIndex: Int?

    public init(service: ModelService) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
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
                    .onDelete(perform: confirmDeleteKeys)
                }
            }

            Divider()

            // Add Key Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("平台", selection: $newProvider) {
                        ForEach(Provider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .frame(width: 100)

                    TextField("名称", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

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
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let index = pendingDeleteIndex {
                    deleteKeys(at: IndexSet(integer: index))
                }
                pendingDeleteIndex = nil
            }
        } message: {
            Text("确定要删除这个 Key 吗？此操作无法撤销。")
        }
    }

    // MARK: - Key Row

    @ViewBuilder
    private func keyRow(for entry: APIKeyEntry, at index: Int) -> some View {
        HStack(spacing: 8) {
            if editingKeyID == entry.id {
                Picker("平台", selection: $editingProvider) {
                    ForEach(Provider.allCases, id: \.self) { p in
                        Text(p.shortTag).tag(p)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            } else {
                Text(entry.provider.shortTag)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.provider == .zhiPu ? Color.blue : Color.purple)
                    )
            }

            if editingKeyID == entry.id {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("名称")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("名称", text: $editingName)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Key")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("API Key", text: $editingKeyValue)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Spacer()
                        Button("取消") {
                            editingKeyID = nil
                            editingName = ""
                            editingKeyValue = ""
                        }
                        Button("保存") {
                            commitEdit(for: entry, at: index)
                        }
                        .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || editingKeyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.vertical, 2)
            } else {
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
                    editingKeyValue = entry.key
                    editingProvider = entry.provider
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button {
                    pendingDeleteIndex = index
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func addKey() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        do {
            try service.addKey(name: trimmedName, key: trimmedKey, provider: newProvider)
            newName = ""
            newKey = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmDeleteKeys(at offsets: IndexSet) {
        keyToDelete = offsets
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

    private func commitEdit(for entry: APIKeyEntry, at index: Int) {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = editingKeyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        do {
            if trimmedName != entry.name {
                try service.renameKey(at: index, newName: trimmedName)
            }
            if trimmedKey != entry.key {
                try service.updateKeyValue(at: index, newKey: trimmedKey)
            }
            if editingProvider != entry.provider {
                try service.updateKeyProvider(at: index, newProvider: editingProvider)
            }
            editingKeyID = nil
            editingName = ""
            editingKeyValue = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
