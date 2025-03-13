//
//  CharactersListView.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//


import SwiftUI
import SwiftData //
import SectionedQuery


struct CharactersListView: View {
    
    init() {
        _sections = CharactersListVM.sectionedQuery()
        
    }
    
    //can be @State, var... not @ObservedObject...
    @Environment(CharactersListVM.self) var viewModel
    @Environment(\.modelContext) var modelContext
    
    @SectionedQuery(\.nameFirstLetter,
                     sort: [SortDescriptor(\.name)])
    private var sections: SectionedResults<String, CharactersListDBModel.PageResult>
    
    private func listCellVM(item: CharactersListDBModel.PageResult) -> CharacterListCellViewModel {
        viewModel.listCellVM(item: item)
    }
    
    var body: some View {
        NavigationStack {
            let seachable = viewModel.searchableTextSubject.binding()
            List(sections) { section in
                Section {
                    ForEach(section) { item in
                        let character = listCellVM(item: item)
                        let isLast = viewModel.isLastCharacter(item,
                                                               sections: sections)
                        CharacterListCell(viewModel: character)
                            .task(priority: isLast ? .background : .userInitiated) { [isLast] in
                                if isLast {
                                    await viewModel.willAppear(characterVM: character)
                                }
                            }
                        if viewModel.isLoading == true, isLast {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            EmptyView()
                        }
                    }
                } header: {
                    Text(section.id)
                }
            }//.id(viewModel.listId)
            .refreshable {
                await viewModel.loadCharactersPage(force: true)
            }
            .alert(isPresented: viewModel.errorDuringLoadSubject.binding()) {
                Alert(title: Text("Failed to load"),
                      message: Text(viewModel.errorLoadingMessage ?? ""),
                      dismissButton: .default(Text("OK")))
            }
            /*.searchable(text: seachable,
                        prompt: Text("Character to search")) */
            .overlay {
                if let scheduled = viewModel.isLoading {
                    if scheduled {
                        ProgressView().progressViewStyle(.circular)
                            .tint(.gray)
                    } else if viewModel.noSearchableText(sections: sections) {
                        ContentUnavailableView.search
                    } else {
                        EmptyView()
                    }
                } else {
                    EmptyView()
                }
            }
            .navigationTitle("Characters List")
        }.task {
            await viewModel.reloadCharacters(once: true) //load once...
        }
    }
}

@MainActor private func charactersListVM(container: ModelContainer) -> CharactersListVM {
    let imageProvider = CachedImageProvider()
    let database = DatabaseService(modelContainer: container)
    return CharactersListVM(service: NetworkService(),
                            database: database,
                            imageProvider: imageProvider)
    
}

#Preview {
    let container = try! DatabaseService.modelContainer(isStoredInMemoryOnly: true)
    CharactersListView()
        .environment(charactersListVM(container: container))
            .modelContainer(container)
}
