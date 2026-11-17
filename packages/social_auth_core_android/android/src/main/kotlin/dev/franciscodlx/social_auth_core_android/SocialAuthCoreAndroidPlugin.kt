package dev.franciscodlx.social_auth_core_android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

/** Runs the sign-in in a Custom Tab and reports the redirect back to Dart. */
class SocialAuthCoreAndroidPlugin :
  FlutterPlugin,
  ActivityAware,
  AuthSessionApi {
  private var context: Context? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    AuthSessionApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    AuthSessionApi.setUp(binding.binaryMessenger, null)
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun isAvailable(): Boolean {
    val probe = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
      .addCategory(Intent.CATEGORY_BROWSABLE)
    return context?.let { probe.resolveActivity(it.packageManager) != null } ?: false
  }

  override suspend fun open(
    url: String,
    callbackUrl: String,
    prefersEphemeralSession: Boolean
  ): String = suspendCoroutine { continuation ->
    val authUri = Uri.parse(url)
    val redirect = Uri.parse(callbackUrl)
    // The Dart layer already restricts plain http to loopback hosts.
    if (authUri.scheme !in listOf("https", "http") || redirect.scheme.isNullOrEmpty()) {
      continuation.resumeWithException(
        FlutterError(AuthSession.INVALID_CONFIG, "The authorization URL must be http(s) and the callback URL absolute")
      )
      return@suspendCoroutine
    }

    // AuthSession hands out the listener exactly once, so the continuation
    // is resumed exactly once.
    val started = AuthSession.begin(redirect, object : AuthSession.Listener {
      override fun onRedirect(url: String) = continuation.resume(url)

      override fun onError(code: String, message: String) =
        continuation.resumeWithException(FlutterError(code, message))
    })
    if (!started) {
      continuation.resumeWithException(
        FlutterError(AuthSession.INVALID_CONFIG, "Another sign-in is already in progress")
      )
      return@suspendCoroutine
    }

    try {
      start(AuthSessionActivity.startIntent(requireContext(), url, prefersEphemeralSession))
    } catch (e: Exception) {
      AuthSession.fail(AuthSession.NOT_SUPPORTED, e.message ?: "Could not start the sign-in")
    }
  }

  override fun cancel() {
    if (AuthSession.isActive) {
      start(AuthSessionActivity.cancelIntent(requireContext()))
    }
  }

  private fun requireContext(): Context =
    activity ?: context ?: throw IllegalStateException("The plugin is not attached to an engine")

  private fun start(intent: Intent) {
    val current = activity
    if (current != null) {
      current.startActivity(intent)
    } else {
      requireContext().startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
  }
}
