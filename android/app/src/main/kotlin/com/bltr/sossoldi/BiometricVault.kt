package com.bltr.sossoldi

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Wraps the card vault key with an AES key that lives in the Android
 * Keystore (hardware-backed where available), usable only right after a
 * strong biometric check, and destroyed when a fingerprint/face is added.
 * The key never leaves the secure hardware, so it cannot be backed up.
 */
class BiometricVault(private val activity: FragmentActivity) {
    private val alias = "sossoldi_card_vault_bio"

    fun status(): String =
        when (BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> "ok"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "none"
            else -> "unavailable"
        }

    fun reset() {
        keyStore().deleteEntry(alias)
    }

    fun encrypt(clear: ByteArray, reason: String, result: MethodChannel.Result) {
        try {
            reset()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, createKey())
            prompt(cipher, reason, result) { c ->
                mapOf("iv" to c.iv, "ct" to c.doFinal(clear))
            }
        } catch (e: Exception) {
            result.error("failed", e.message, null)
        }
    }

    fun decrypt(iv: ByteArray, ct: ByteArray, reason: String, result: MethodChannel.Result) {
        try {
            val key = keyStore().getKey(alias, null) as? SecretKey
            if (key == null) {
                result.error("invalidated", "No biometric key", null)
                return
            }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
            prompt(cipher, reason, result) { c -> c.doFinal(ct) }
        } catch (e: KeyPermanentlyInvalidatedException) {
            reset()
            result.error("invalidated", "Biometrics changed", null)
        } catch (e: Exception) {
            result.error("failed", e.message, null)
        }
    }

    private fun prompt(
        cipher: Cipher,
        reason: String,
        result: MethodChannel.Result,
        onReady: (Cipher) -> Any,
    ) {
        var answered = false
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                if (answered) return
                answered = true
                try {
                    result.success(onReady(r.cryptoObject!!.cipher!!))
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }

            override fun onAuthenticationError(code: Int, message: CharSequence) {
                if (answered) return
                answered = true
                val cancelled = code == BiometricPrompt.ERROR_USER_CANCELED ||
                    code == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                    code == BiometricPrompt.ERROR_CANCELED
                result.error(if (cancelled) "cancelled" else "failed", message.toString(), null)
            }
        }
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(reason)
            .setNegativeButtonText("Use passphrase")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .build()
        BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
            .authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }

    private fun createKey(): SecretKey {
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(builder.build())
        return generator.generateKey()
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
}
