# Schedule App

Ứng dụng lịch trình với tính năng đăng nhập và đăng ký.

## Tính năng

### Đăng nhập
- ✅ Giao diện đăng nhập đẹp mắt với gradient background
- ✅ Validation email và mật khẩu
- ✅ Toggle hiện/ẩn mật khẩu (icon mắt)
- ✅ Ghi nhớ mật khẩu (checkbox)
- ✅ Loading state khi đăng nhập
- ✅ Thông báo lỗi chi tiết
- ✅ Chuyển đến màn hình đăng ký

### Đăng ký
- ✅ Giao diện đăng ký với form validation
- ✅ Nhập họ và tên, email, mật khẩu
- ✅ Xác nhận mật khẩu
- ✅ Toggle hiện/ẩn mật khẩu cho cả 2 trường
- ✅ Validation đầy đủ
- ✅ Loading state khi đăng ký
- ✅ Chuyển về màn hình đăng nhập sau khi đăng ký thành công

## Công nghệ sử dụng

- **Flutter**: Framework UI
- **Firebase Auth**: Xác thực người dùng
- **Shared Preferences**: Lưu trữ thông tin đăng nhập

## Cài đặt

1. Clone repository
2. Chạy `flutter pub get` để cài đặt dependencies
3. Cấu hình Firebase (nếu chưa có)
4. Chạy `flutter run` để khởi động ứng dụng

## Cấu trúc thư mục

```
lib/
├── main.dart              # Entry point
└── screens/
    ├── login_screen.dart  # Màn hình đăng nhập
    └── register_screen.dart # Màn hình đăng ký
```

## Tính năng bảo mật

- Mật khẩu được mã hóa khi lưu trữ
- Validation email format
- Kiểm tra độ mạnh mật khẩu
- Xác nhận mật khẩu khi đăng ký
