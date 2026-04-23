import PhotosUI
import SwiftUI

struct CaptureMomentView: View {
    let pairID: UUID
    @StateObject private var viewModel = CaptureViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 14) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.gray.opacity(0.15))
                    .frame(height: 280)
                    .overlay(Text("Add a selfie"))
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Pick Photo")
            }

            TextField("Say something sweet...", text: $viewModel.text, axis: .vertical)
                .lineLimit(3)
                .textFieldStyle(.roundedBorder)

            Button(viewModel.isUploading ? "Uploading..." : "Share Moment") {
                guard let image else { return }
                Task { await viewModel.uploadMoment(image: image, pairID: pairID) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isUploading || image == nil || viewModel.text.isEmpty)

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .padding()
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                image = UIImage(data: data)
            }
        }
    }
}
