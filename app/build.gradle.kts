plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
// gradle.properties boş ya da örnek değerde kalsa bile uygulamanın kendi anahtarı kullanılır (App key gizli bilgi değildir)
val dropboxKey: String = (project.findProperty("DROPBOX_APP_KEY") as String?)?.trim().orEmpty()
    .let { if (it.isEmpty() || it == "YOUR_DROPBOX_APP_KEY") "01a5zg8oc8aas3c" else it }
android {
    namespace = "io.github.idrisokys.linkcepte"
    compileSdk = 34
    defaultConfig {
        applicationId = "io.github.idrisokys.linkcepte"
        minSdk = 24; targetSdk = 34; versionCode = 2; versionName = "1.1"
        resourceConfigurations += listOf("tr", "en")
        buildConfigField("String", "DROPBOX_APP_KEY", "\"$dropboxKey\"")
        manifestPlaceholders["dropboxScheme"] = "db-$dropboxKey"
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    lint { checkReleaseBuilds = false; abortOnError = false }
    packaging { resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" } }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.0")
}
