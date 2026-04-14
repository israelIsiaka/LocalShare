# LocalShare

Fast, private file sharing over your local WiFi network. No internet, no accounts, no cloud.

LocalShare is a cross-platform Flutter application that allows you to share files between devices on the same WiFi network securely and quickly. Whether you're sharing photos, documents, videos, or any other files, LocalShare makes it simple without relying on external services or the internet.

## Features

- **Local Network Sharing**: Share files directly over your WiFi network without needing internet access.
- **Cross-Platform**: Supports Android, iOS, macOS, and Windows.
- **Secure**: Files are transferred directly between devices, ensuring privacy.
- **Easy to Use**: Simple interface for selecting and sending files.
- **No Accounts Required**: No sign-ups, logins, or cloud storage needed.
- **Fast Transfers**: Optimized for quick file sharing on local networks.

## Installation

### Prerequisites

- Flutter SDK installed on your machine. [Install Flutter](https://flutter.dev/docs/get-started/install)
- A device or emulator for testing (Android/iOS simulator, or physical device)

### Clone the Repository

```bash
git clone https://github.com/israelIsiaka/LocalShare.git
cd LocalShare
```

### Install Dependencies

```bash
flutter pub get
```

### Run the App

For Android:
```bash
flutter run
```

For iOS (on macOS):
```bash
flutter run
```

For macOS:
```bash
flutter run -d macos
```

For Windows:
```bash
flutter run -d windows
```

## Usage

1. Ensure both devices are connected to the same WiFi network.
2. Open LocalShare on both devices.
3. On the sending device, select the files you want to share.
4. Choose the receiving device from the list of available devices on the network.
5. Send the files.
6. On the receiving device, accept the incoming files.

## Building for Release

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

### macOS

```bash
flutter build macos --release
```

### Windows

```bash
flutter build windows --release
```

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you have any questions or issues, please open an issue on GitHub or contact the maintainers.
