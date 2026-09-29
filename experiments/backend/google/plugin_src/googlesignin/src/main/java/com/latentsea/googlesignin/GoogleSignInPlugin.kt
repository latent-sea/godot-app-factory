package com.latentsea.googlesignin

import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Native Google sign-in through the Android Credential Manager account picker. */
class GoogleSignInPlugin(godot: Godot) : GodotPlugin(godot) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun getPluginName() = "GoogleSignIn"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("signed_in", String::class.java, String::class.java),
        SignalInfo("sign_in_failed", String::class.java),
    )

    private fun fail(message: String) {
        Log.w(TAG, message)
        emitSignal("sign_in_failed", message)
    }

    @UsedByGodot
    fun signIn(serverClientId: String, hashedNonce: String) {
        val context = activity
        if (context == null) {
            fail("NoActivity: plugin has no activity")
            return
        }
        val option = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(serverClientId)
            .setNonce(hashedNonce)
            .setAutoSelectEnabled(false)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        scope.launch {
            try {
                val response: GetCredentialResponse =
                    CredentialManager.create(context).getCredential(context, request)
                handle(response)
            } catch (e: GetCredentialException) {
                fail("${e.javaClass.name} [${e.type}]: ${e.message}")
            } catch (e: Throwable) {
                fail("${e.javaClass.name}: ${e.message}")
            }
        }
    }

    private fun handle(response: GetCredentialResponse) {
        val credential = response.credential
        if (credential is CustomCredential &&
            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            try {
                val google = GoogleIdTokenCredential.createFrom(credential.data)
                emitSignal("signed_in", google.idToken, google.id)
            } catch (e: Throwable) {
                fail("${e.javaClass.name}: ${e.message}")
            }
        } else {
            fail("UnexpectedCredential: ${credential.javaClass.name} type=${credential.type}")
        }
    }

    companion object {
        private const val TAG = "GoogleSignIn"
    }
}
