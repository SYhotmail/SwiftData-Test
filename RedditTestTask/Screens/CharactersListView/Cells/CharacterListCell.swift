//
//  CharacterListCell.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import SwiftUI

struct CharacterListCell: View {
    var viewModel: CharacterListCellViewModel
    
    var body: some View {
        VStack {
            HStack {
                AsyncImage(url: viewModel.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                        .scaledToFit()
                        .onAppear {
                            viewModel.loadedImage() //
                        }
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
