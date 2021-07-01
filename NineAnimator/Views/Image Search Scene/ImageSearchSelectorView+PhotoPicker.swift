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

import NineAnimatorCommon
import PhotosUI
import SwiftUI

@available(iOS 14.0, *)
extension ImageSearchSelectorView {
    struct PhotoPicker: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        @Binding var selectedImageState: ImageSearchSelectorView.ImageUploadState
        @Binding var selectedImage: ImageSearchSelectorView.SelectedImage

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.preferredAssetRepresentationMode = .compatible
            let controller = PHPickerViewController(configuration: configuration)
            controller.delegate = context.coordinator
            return controller
        }

        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: PHPickerViewControllerDelegate {
            private let parent: PhotoPicker

            init(_ parent: PhotoPicker) {
                self.parent = parent
            }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                self.parent.isPresented = false

                guard let item = results.first?.itemProvider else { return }

                guard item.canLoadObject(ofClass: UIImage.self) else {
                    Log.error("[PhotoPickerController] Cannot load imported image: %@", item)
                    return self.parent.selectedImageState = .errored(
                        error: NineAnimatorError.unknownError("Unable to import this image: \(item)")
                    )
                }
                
                self.parent.selectedImageState = .downloading
                item.loadObject(ofClass: UIImage.self) {
                    image, error in

                    guard error == nil else {
                        Log.error(error)
                        return self.parent.selectedImageState = .errored(error: error!)
                    }
                    guard let image = image as? UIImage else {
                        Log.error("[PhotoPickerController] Could not convert item to image")
                        return self.parent.selectedImageState = .errored(
                            error: NineAnimatorError.unknownError("Could not convert item to image")
                        )
                    }

                    self.parent.selectedImage = .localImage(image)
                    self.parent.selectedImageState = .completed
                }
            }
        }
    }
}
