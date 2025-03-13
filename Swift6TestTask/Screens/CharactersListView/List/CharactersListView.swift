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
    
    @SectionedQuery(\.nameFirstLetter)
    private var sections: SectionedResults<String, CharactersListDBModel.PageResult>
    
    private func listCellVM(item: CharactersListDBModel.PageResult) -> CharacterListCellViewModel {
        viewModel.listCellVM(item: item)
    }
    
    var body: some View {
        NavigationStack {
            List(sections.enumerated()) { index, section in
                
                Section {
                    ForEach(section.enumerated) { rowIndex, item in
                        
                        let character = listCellVM(item: item)
                        CharacterListCell(viewModel: character)
                            .task {
                                await viewModel.willAppear(characterVM: character)
                            }
                        if viewModel.isLoading, index == sections.count - 1, rowIndex == section.items.count - 1 {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            EmptyView()
                        }
                    }
                } header: {
                    Text(section.id)
                }
            }.refreshable(action: {
                Task(priority: .userInitiated) {
                    viewModel.loadCharactersPage(force: true)
                }
            })
            .alert(isPresented: viewModel.errorDuringLoadSubject.binding()) {
                Alert(title: Text("Failed to load"),
                      message: Text(viewModel.errorLoadingMessage ?? ""),
                      dismissButton: .default(Text("OK")))
            } //Search wasn't in the task...
            .searchable(text: viewModel.searchableTextSubject.binding(),
                        prompt: Text("Character to search"))
            .onReceive(viewModel.searchableTextSubject.removeDuplicates().eraseToAnyPublisher(), perform: { text in
                //_sections = CharactersListVM.sectionedQuery(text: text)
            })
            .overlay {
                if let scheduled = viewModel.isLoading {
                    if scheduled {
                        ProgressView().progressViewStyle(.circular)
                            .tint(.gray)
                    } else if let filteredCharacterSections = viewModel.filteredCharacterSections, filteredCharacterSections.isEmpty {
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

#Preview {
    let container = try! DatabaseService.modelContainer(isStoredInMemoryOnly: true)
    let imageProvider = CachedImageProvider()
    CharactersListView()
        .environment(CharactersListVM(service: NetworkService(),
                                      database: DatabaseService(container: container,
                                                                imageProvider: imageProvider),
                                      imageProvider: imageProvider))
        .modelContainer(container)
}
