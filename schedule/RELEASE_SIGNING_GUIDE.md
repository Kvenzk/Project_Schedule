# Hướng dẫn tạo Release Signing cho Flutter App

## Vấn đề hiện tại
Bạn đang gặp lỗi khi tải lên file `app-release.aab` vì file này được ký ở chế độ debug thay vì release mode.

## Giải pháp

### Bước 1: Tạo Keystore
Chạy lệnh sau trong terminal tại thư mục gốc của dự án:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Lưu ý quan trọng:**
- Ghi nhớ mật khẩu keystore và key alias
- Lưu trữ keystore file an toàn
- Backup keystore file

### Bước 2: Tạo file key.properties
Tạo file `android/key.properties` với nội dung:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=upload-keystore.jks
```

**Thay thế:**
- `<your-store-password>`: Mật khẩu keystore bạn đã tạo
- `<your-key-password>`: Mật khẩu key bạn đã tạo

### Bước 3: Cập nhật build.gradle.kts
Cập nhật file `android/app/build.gradle.kts`:

```kotlin
// Thêm vào đầu file, sau phần plugins
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    
    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
```

### Bước 4: Build Release APK/AAB
Sau khi cấu hình xong, build lại:

```bash
# Build APK
flutter build apk --release

# Hoặc build AAB (khuyến nghị cho Google Play)
flutter build appbundle --release
```

### Bước 5: Kiểm tra
File build sẽ được tạo tại:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Lưu ý bảo mật
1. **KHÔNG** commit file `key.properties` và `upload-keystore.jks` vào git
2. Thêm vào `.gitignore`:
   ```
   android/key.properties
   android/app/upload-keystore.jks
   ```
3. Backup keystore file ở nơi an toàn
4. Nếu mất keystore, bạn sẽ không thể cập nhật app trên Google Play

## Troubleshooting
- Nếu gặp lỗi "keystore not found", kiểm tra đường dẫn trong `key.properties`
- Nếu gặp lỗi "password incorrect", kiểm tra lại mật khẩu
- Đảm bảo file `key.properties` được tạo đúng định dạng 