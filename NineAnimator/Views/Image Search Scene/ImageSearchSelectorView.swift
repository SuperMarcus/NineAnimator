//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2020 Marcus Zhou. All rights reserved.
//
//  NineAnimator is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  NineAnimator is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with NineAnimator.  If not, see <http://www.gnu.org/licenses/>.
//

import Kingfisher
import NineAnimatorCommon
import NineAnimatorNativeListServices
import SwiftUI

@available(iOS 14.0, *)
struct ImageSearchSelectorView: View {
    private let traceMoeEngine = TraceMoe()
    @State private var selectedImage: SelectedImage = .none
    @State private var imageUploadState: ImageUploadState = .completed

    @State private var inputTextURL = ""

    @State private var shouldDisplayError = false
    @State private var shouldDisplayPhotoPicker = false

    @State private var searchResults: [TraceMoe.TraceMoeSearchResult] = []
    @State private var shouldDisplayResultsView: Bool = false

    var body: some View {
        // To-Do: Remove VStack if i plan not to use it
        VStack {
            Form {
                ImagePreview(
                    selectedImage: $selectedImage,
                    imageState: $imageUploadState,
                    shouldDisplayError: $shouldDisplayError)
                    .scaledToFit()
                    .listRowInsets(EdgeInsets())
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 300, maxHeight: 300, alignment: .center)
                Section(header: Text("ENTER IMAGE LINK")) {
                    HStack {
                        TextField("Enter URL", text: $inputTextURL, onEditingChanged: { _ in }, onCommit: { loadInputURL() })
                            .textFieldStyle(PlainTextFieldStyle())
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        Button("Load URL") { loadInputURL() }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(Color.accentColor)
                    }
                }
                Section(header: Text("UPLOAD IMAGE")) {
                    Button("Select Image From Library") {
                        shouldDisplayPhotoPicker = true
                    }
                }
                Button(action: { uploadImage() }, label: {
                    if case .uploading = imageUploadState {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("UPLOAD")
                            .frame(maxWidth: .infinity)
                    }
                })
                .disabled(isUploadButtonDisabled)
            }
            NavigationLink(destination: ImageSearchResultsView(searchResults: $searchResults), isActive: $shouldDisplayResultsView) { EmptyView() }
        }
        .sheet(
            isPresented: $shouldDisplayPhotoPicker,
            onDismiss: {
                // Displacing error alert after
                // photo picker is dismissed to
                // avoid weird animation
                if case .errored = imageUploadState {
                    shouldDisplayError = true
                }
            }, content: {
                PhotoPicker(
                    isPresented: $shouldDisplayPhotoPicker,
                    selectedImageState: $imageUploadState,
                    selectedImage: $selectedImage
                )
            }
        )
        .alert(isPresented: $shouldDisplayError) {
            generateErrorAlert()
        }
        .navigationTitle("Image Search")
    }

    private var isUploadButtonDisabled: Bool {
        if selectedImage != .none,
           case .completed = imageUploadState {
            return false
        } else { return true }
    }

    private var uploadButtonColor: Color {
        isUploadButtonDisabled ? .gray : .accentColor
    }
}

// View methods
@available(iOS 14.0, *)
private extension ImageSearchSelectorView {
    func loadInputURL() {
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard !inputTextURL.isEmpty else { return }
        // Add https:// prefix for the lazy humans
        var selectedText = inputTextURL
        if !selectedText.hasPrefix("https://") {
            selectedText = "https://\(selectedText)"
        }
        guard let URL = URL(string: selectedText) else {
            imageUploadState = .errored(error: NineAnimatorError.urlError)
            selectedImage = .none
            return
        }
        imageUploadState = .downloading
        selectedImage = .remoteURL(URL)
    }
    
    func uploadImage() {
        func handleError(_ error: Error) {
            Log.error("[ImageSearchSelectorView] Failed To Upload Image: %@", error)
            imageUploadState = .errored(error: error)
            shouldDisplayError = true
        }
        
        func handleResult(_ results: [TraceMoe.TraceMoeSearchResult]) {
            imageUploadState = .completed
            searchResults = results
            shouldDisplayResultsView = true
        }
        
        switch selectedImage {
        case .none:
            Log.error("[ImageSearchSelectorView] Tried Uploading Without A Selected Image")
        case let .localImage(localImage):
            imageUploadState = .uploading(task: traceMoeEngine.search(with: localImage)
                .error { handleError($0) }
                .finally { handleResult($0) })
        case let .remoteURL(url):
            imageUploadState = .uploading(task: traceMoeEngine.search(with: url)
                .error { handleError($0) }
                .finally { handleResult($0) })
        }
    }

    func generateErrorAlert() -> Alert {
        guard case let .errored(error) = imageUploadState else {
            return Alert(
                title: Text("Unknown Error"),
                message: Text("Unknown Error"),
                dismissButton: .default(Text("OK")) {
                    selectedImage = .none
                    imageUploadState = .completed
                }
            )
        }

        var errorMessage: String
        if let nineError = error as? NineAnimatorError {
            errorMessage = nineError.description
        } else if let kingFisherError = error as? KingfisherError {
            errorMessage = kingFisherError.shortenedDescription
        } else {
            errorMessage = error.localizedDescription
        }

        return Alert(
            title: Text("Error"),
            message: Text(errorMessage),
            dismissButton: .default(Text("OK")) {
                selectedImage = .none
                imageUploadState = .completed
            }
        )
    }
}

// Internal State
@available(iOS 14.0, *)
extension ImageSearchSelectorView {
    enum ImageUploadState {
        /// The selected image has been downloaded/uploaded
        case completed

        /// The selected image is downloading for previewing
        case downloading

        /// The selected image is being uploaded to retrieve search results
        case uploading(task: NineAnimatorAsyncTask)

        /// The selected image has failed to download/upload
        case errored(error: Error)
    }
    
    enum SelectedImage: Hashable {
        /// Represents an image stored on the user's device
        case localImage(UIImage)

        /// Represents a URL pointing to an image stored remotely
        case remoteURL(URL)
        
        /// No image has been selected
        case none
    }
}

@available(iOS 14.0, *)
private extension ImageSearchSelectorView {
    struct ImagePreview: View {
        @Binding fileprivate var selectedImage: SelectedImage
        @Binding fileprivate var imageState: ImageUploadState
        @Binding fileprivate var shouldDisplayError: Bool
        
        var body: some View {
            switch selectedImage {
            case .none:
                // Display Default Placeholder Image
                Image("NineAnimator Lists Tip")
                    .resizable()
            case let .localImage(image):
                Image(uiImage: image)
                    .resizable()
            case let .remoteURL(url):
                KFImage(url)
                    .fade(duration: 0.5)
                    .resizable()
                    .placeholder {
                        ProgressView()
                            .scaleEffect(2)
                    }
                    .onSuccess { _ in
                        // SwiftUI will force kingfisher to reload many times 🤦‍♂️
                        // This guard statement will ensure internal state does not get
                        // updated unless image was actually being requested to download.
                        guard case .downloading = imageState else { return }
                        imageState = .completed
                    }
                    .onFailure { error in
                        guard case .downloading = imageState else { return }
                        Log.error(error)
                        selectedImage = .none
                        imageState = .errored(error: error)
                        shouldDisplayError = true
                    }
                    // Loading image immediately to fix bug
                    // https://github.com/onevcat/Kingfisher/issues/1660
                    .loadImmediately()
            }
        }
    }
}

@available(iOS 14.0, *)
struct ImageSelector_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ImageSearchSelectorView().preferredColorScheme(.light)
        }
    }
}
