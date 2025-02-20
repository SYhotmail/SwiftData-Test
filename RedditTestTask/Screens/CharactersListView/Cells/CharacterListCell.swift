//
//  CharacterListCell.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import SwiftUI

final class CharactersSectionViewModel: ObservableObject, Identifiable {
    let pageInfo: CharactersListModel.PageInfo
    @Published var characters = [CharacterListCellViewModel]()
    
    var id: Int { pageInfo.pages }
    
    convenience init(model: CharactersListModel) {
        self.init(pageInfo: model.info,
                  characters: model.results.map { .init(model: $0) })
    }
    
    init(pageInfo: CharactersListModel.PageInfo,
         characters: [CharacterListCellViewModel]) {
        self.pageInfo = pageInfo
        self.characters = characters
    }
}

final class CharacterListCellViewModel: ObservableObject, Identifiable {
    @Published var imageURL: URL?
    @Published var officialName: String
    
    let model: CharactersListModel.PageResult
    
    var id: Int { model.id }
    
    private var retryCount = 0
    
    @Published var altMessage: String?
    @Published var frameWidth: CGFloat? = 50
    
    init(model: CharactersListModel.PageResult) {
        self.model = model
        imageURL = model.image.flatMap { .init(string: $0) }
        officialName = model.name
    }
    
    func failedToLoadImage(error: Error) {
        debugPrint("!!! error \(error)")
        if retryCount > 2 {
            altMessage = "Failed"
            //frameWidth = nil
        }
        
        retryCount += 1
    }
}

struct CharacterListCell: View {
    @ObservedObject var viewModel: CharacterListCellViewModel
    
    var body: some View {
        VStack {
            HStack {
                AsyncImage(url: viewModel.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                        .scaledToFit()
                    } else if let error = phase.error {
                        ZStack {
                            if let message = viewModel.altMessage {
                                Text(message)
                                    .padding(10)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                            } else {
                                Image(systemName: "repeat.circle.fill")
                                    .onTapGesture {
                                        viewModel.failedToLoadImage(error: error)
                                    }
                            }
                        }
                    } else {
                        ProgressView().progressViewStyle(.circular)
                    }
                }
                .frame(width: viewModel.frameWidth)
                .border(.gray, width: 1)
                
                Text(viewModel.officialName)
                    .layoutPriority(viewModel.frameWidth == nil ? 1 : 0)
                Spacer()
            }
        }
    }
}
