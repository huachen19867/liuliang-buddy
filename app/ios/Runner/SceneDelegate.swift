import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts {
      (UIApplication.shared.delegate as? AppDelegate)?.handleWidgetURL(context.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let unhandled = URLContexts.filter {
      !((UIApplication.shared.delegate as? AppDelegate)?.handleWidgetURL($0.url) ?? false)
    }
    if !unhandled.isEmpty {
      super.scene(scene, openURLContexts: Set(unhandled))
    }
  }
}
