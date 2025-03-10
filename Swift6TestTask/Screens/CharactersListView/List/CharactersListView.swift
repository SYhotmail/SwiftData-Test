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
        _sections = .init(\.nameFirstLetter,
                           sort: [SortDescriptor(\.name,
                                                  order: .reverse)])
    }
    
    //can be @State, var... not @ObservedObject...
    @Environment(CharactersListVM.self) var viewModel
    @Environment(\.modelContext) var modelContext {
        didSet {
            updateModelContext()
        }
    }
    
    @SectionedQuery(\.nameFirstLetter,
                     sort: [SortDescriptor(\.name,
                                            order: .reverse)])
    private var sections: SectionedResults<String, CharactersListDBModel.PageResult>
    
    var body: some View {
        NavigationStack {
            List(viewModel.filteredCharacterSections ?? []) { section in
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
            .alert(isPresented: viewModel.errorDuringLoadSubject.binding()) {
                Alert(title: Text("Failed to load"),
                      message: Text(viewModel.errorLoadingMessage ?? ""),
                      dismissButton: .default(Text("OK")))
            } //Search wasn't in the task...
            .searchable(text: viewModel.searchableTextSubject.binding(),
                        prompt: Text("Character to search"))
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
        }
        .onAppear {
            updateModelContext() //just for safety..
            viewModel.reloadCharacters(once: true) //load once...
        }
    }
    
    private func updateModelContext() {
        viewModel.modelContext = modelContext
    }
}

#Preview {
    CharactersListView()
        .environment(CharactersListVM(service: NetworkService(),
                                      imageProvider: ProcessingActor()))
        .modelContainer(try! DatabaseService.modelContainer(isStoredInMemoryOnly: true))
}
