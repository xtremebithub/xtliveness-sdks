plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    namespace = "com.xtremebit.xtliveness"
    compileSdk = 34
    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    publishing { singleVariant("release") { withSourcesJar() } }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")   // the JVM has no org.json; Android does
}

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "com.xtremebit"
            artifactId = "xtliveness"
            version = "1.0.0"
            afterEvaluate { from(components["release"]) }
            pom {
                name.set("xtliveness for Android")
                description.set("Face liveness check for Android apps: runs the hosted check in a WebView with the camera.")
                licenses { license { name.set("BSD 3-Clause"); url.set("https://opensource.org/licenses/BSD-3-Clause") } }
            }
        }
    }
}
