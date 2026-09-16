allprojects {
    repositories {
        // Miroir local des artefacts du moteur Flutter (io.flutter:*) :
        // certains réseaux coupent les gros téléchargements depuis
        // download.flutter.io ("Tag mismatch"). Peuplé par script avec des
        // téléchargements à reprise ; ignoré si le dossier n'existe pas.
        val engineMirror = file("${System.getProperty("user.home")}/.flutter_engine_mirror")
        if (engineMirror.exists()) {
            maven { url = uri(engineMirror) }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
