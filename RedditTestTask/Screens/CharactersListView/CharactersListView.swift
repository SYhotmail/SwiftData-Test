//
//  CharactersListView.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//


import SwiftUI
import SwiftData //

struct CharactersListView: View {
    @ObservedObject var viewModel: CharactersListVM
    @Environment(\.modelContext) var modelContext {
        didSet {
            viewModel.modelContext = modelContext
        }
    }
    
    var body: some View {
        NavigationStack {
            List(viewModel.filteredCharacterSections) { section in
                Section {
                    ForEach(section.characters) { character in
                        CharacterListCell(viewModel: character)
                            .onAppear {
                                viewModel.willAppear(characterVM: character)
                            }
                        
                        if viewModel.isLoadingAndLastRow(characterVM: character) {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            EmptyView()
                        }
                    }
                }
            }.refreshable(action: {
                Task(priority: .userInitiated) {
                    viewModel.loadCharactersPage(force: true)
                }
            })
            .alert(isPresented: $viewModel.errorDuringLoad) {
                Alert(title: Text("Failed to load"),
                      message: Text(viewModel.errorLoadingMessage ?? ""),
                      dismissButton: .default(Text("OK")))
            } //Search wasn't in the task...
            /*.searchable(text: $viewModel.searchableText, prompt: Text("Character to search")) */
            .overlay {
                if let scheduled = viewModel.isLoading {
                    if scheduled {
                        ProgressView().progressViewStyle(.circular)
                            .tint(.gray)
                    }
                    else if viewModel.filteredCharacterSections.isEmpty {
                        EmptyView()
                        //ContentUnavailableView.search
                    } else {
                        EmptyView()
                    }
                } else {
                    EmptyView()
                }
            }
            .navigationTitle("Characters List")
        }
        .onAppear {
            viewModel.modelContext = modelContext //just for safety..
            viewModel.reloadCharacters(once: true) //load once...
        }
    }
}

private extension ModelContainer {
    static func new() throws -> ModelContainer {
        let schema = Schema([CharactersListDBModel.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return container
    }
}

#Preview {
    CharactersListView(viewModel: .init(service: NetworkService()))
        .modelContainer(try! ModelContainer.new())
}
