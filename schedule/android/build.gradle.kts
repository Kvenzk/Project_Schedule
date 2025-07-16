// Cấu hình buildscript để tải plugin Firebase
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

// Đảm bảo tất cả subprojects đều dùng đúng repositories
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// (Tuỳ chọn) Đổi thư mục build chung để dễ quản lý
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    evaluationDependsOn(":app")
}

// Nhiệm vụ dọn dẹp build
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
