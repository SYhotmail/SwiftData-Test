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
                Group {
                    if let image = viewModel.localImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if let message = viewModel.altMessage {
                        Text(message)
                            .padding(10)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    } else if viewModel.isLoading  {
                        /*Image(systemName: "repeat.circle.fill")
                         .onTapGesture {
                         viewModel.failedToLoadImage(error: error)
                         } */
                        ProgressView().progressViewStyle(.circular)
                    } else if !viewModel.imageCanBeLoaded {
                        Image(systemName: "repeat.circle.fill")
                            .onTapGesture(perform: viewModel.reload)
                    } else {
                        EmptyView().onAppear {
                            assert(false, "can't be here!")
                        }
                    }
                }
                .frame(width: viewModel.frameWidth)
                .border(.gray, width: 1)
                
                Text(viewModel.officialName)
                    .layoutPriority(viewModel.frameWidth == nil ? 1 : 0)
                Spacer()
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDissappear)
    }
}
