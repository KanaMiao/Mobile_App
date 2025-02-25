import UIKit
import AVFoundation
import Photos
import CoreLocation

//
// MARK: - CameraViewController
//
class CameraViewController: UIViewController {

    // MARK: - AVFoundation
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - UI: Nút chụp (tự co giãn theo text)
    private let captureButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Chụp ảnh", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .systemBlue
        btn.titleLabel?.font = UIFont(name: "Times New Roman", size: 22)
        btn.clipsToBounds = true
        return btn
    }()

    // MARK: - Location
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private let geocoder = CLGeocoder()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCamera()
        setupUI()
        setupLocation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Preview toàn màn hình
        previewLayer?.frame = view.bounds

        // Tự co giãn nút chụp theo text
        captureButton.sizeToFit()
        // Thêm padding cho đẹp
        captureButton.frame.size.width += 30
        captureButton.frame.size.height += 10

        // Bo góc (dạng pill)
        captureButton.layer.cornerRadius = captureButton.frame.height / 2

        // Đặt vị trí nút chụp
        captureButton.frame.origin.x = (view.bounds.width - captureButton.frame.width) / 2
        captureButton.frame.origin.y = view.bounds.height - captureButton.frame.height - 50
    }

    // MARK: - Thiết lập camera
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("Không tìm thấy camera sau.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            captureSession.beginConfiguration()
            // Xoá input cũ (nếu có)
            if let oldInput = captureSession.inputs.first {
                captureSession.removeInput(oldInput)
            }
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            if captureSession.outputs.isEmpty {
                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                }
            }
            captureSession.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            previewLayer = layer

            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        } catch {
            print("Lỗi setup camera: \(error.localizedDescription)")
        }
    }

    // MARK: - UI
    private func setupUI() {
        view.addSubview(captureButton)
        captureButton.addTarget(self, action: #selector(didTapCapture), for: .touchUpInside)
    }

    // MARK: - Xử lý chụp ảnh
    @objc private func didTapCapture() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Quản lý vị trí
    private func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard let data = photo.fileDataRepresentation(),
              let originalImage = UIImage(data: data) else {
            print("Lỗi chuyển ảnh.")
            return
        }

        // Lấy vị trí
        if let loc = currentLocation {
            geocoder.reverseGeocodeLocation(loc) { placemarks, err in
                let addressString: String
                if let p = placemarks?.first, err == nil {
                    let name = p.name ?? ""
                    let subLocal = p.subLocality ?? ""
                    let city = p.locality ?? ""
                    addressString = [name, subLocal, city]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                } else {
                    addressString = "(Không tìm được địa chỉ)"
                }

                let stampedImg = originalImage.withVietnameseTimeAndPlace(placeName: addressString)
                    ?? originalImage

                self.saveAndPresent(stampedImg)
            }
        } else {
            let stampedImg = originalImage.withVietnameseTimeAndPlace(placeName: "(Không có địa chỉ)")
                ?? originalImage
            saveAndPresent(stampedImg)
        }
    }

    /// Lưu ảnh vào Photos, sau đó mở màn hình preview
    private func saveAndPresent(_ image: UIImage) {
        var newAssetID: String?
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
            newAssetID = req.placeholderForCreatedAsset?.localIdentifier
        }, completionHandler: { success, err in
            if let e = err {
                print("Lưu ảnh thất bại: \(e.localizedDescription)")
            } else {
                print("Ảnh đã lưu. ID = \(newAssetID ?? "nil")")
            }
            DispatchQueue.main.async {
                let previewVC = ImagePreviewViewController(image: image)
                previewVC.assetIdentifier = newAssetID
                self.present(previewVC, animated: true, completion: nil)
            }
        })
    }
}

// MARK: - CLLocationManagerDelegate
extension CameraViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("Lỗi lấy GPS: \(error.localizedDescription)")
    }
}

//
// MARK: - ImagePreviewViewController: xem và xoá ảnh (có xác nhận)
//
class ImagePreviewViewController: UIViewController {
    private let imageView = UIImageView()
    var assetIdentifier: String?

    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Đóng", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .gray
        btn.layer.cornerRadius = 6
        btn.clipsToBounds = true
        return btn
    }()
    
    private let deleteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Xoá ảnh", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 6
        btn.clipsToBounds = true
        return btn
    }()

    init(image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)

        view.addSubview(closeButton)
        view.addSubview(deleteButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds

        closeButton.frame = CGRect(x: 20, y: 40, width: 80, height: 40)
        deleteButton.frame = CGRect(
            x: view.bounds.width - 100,
            y: 40,
            width: 80,
            height: 40
        )
    }

    @objc private func didTapClose() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func didTapDelete() {
        guard let assetId = assetIdentifier else {
            print("Không có ID ảnh để xóa.")
            dismiss(animated: true, completion: nil)
            return
        }

        // Hỏi xác nhận xoá
        let alert = UIAlertController(title: "Xác nhận",
                                      message: "Bạn có chắc muốn xoá ảnh này?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Xoá", style: .destructive, handler: { _ in
            // Thực hiện xoá
            PHPhotoLibrary.shared().performChanges({
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                if let asset = assets.firstObject {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
            }, completionHandler: { success, err in
                if let e = err {
                    print("Xoá ảnh thất bại: \(e.localizedDescription)")
                } else {
                    print("Ảnh đã được xóa khỏi Photos.")
                }
            })
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
}

//
// MARK: - UIImage Extension: chèn watermark
//
extension UIImage {
    /// Chèn thời gian (tiếng Việt) + tên địa điểm vào góc dưới phải.
    func withVietnameseTimeAndPlace(placeName: String) -> UIImage? {
        // 1. Thời gian tiếng Việt
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateText = formatter.string(from: Date())

        // Gộp 2 dòng
        let finalText = dateText + "\n" + placeName

        // 2. Mở context
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        // 3. Vẽ ảnh gốc
        draw(in: CGRect(origin: .zero, size: size))

        // 4. Thuộc tính text
        let font = UIFont.systemFont(ofSize: 22)
        let textColor = UIColor.white
        let bgColor = UIColor.black.withAlphaComponent(0.5)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.alignment = .right

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .backgroundColor: bgColor,
            .paragraphStyle: paragraph
        ]

        let attrString = NSAttributedString(string: finalText, attributes: attrs)
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let textSize = boundingRect.size

        let margin: CGFloat = 10
        let xPos = size.width - textSize.width - margin
        let yPos = size.height - textSize.height - margin-100
        let textRect = CGRect(x: xPos, y: yPos, width: textSize.width, height: textSize.height)

        // 5. Vẽ text
        attrString.draw(with: textRect, options: .usesLineFragmentOrigin, context: nil)

        // 6. Lấy ảnh mới
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
