# flutter_secure_storage(Tink)가 컴파일 시에만 쓰는 애너테이션. release R8 축소에서 누락 클래스로 빌드가 멈춰 경고만 끈다.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
