package com.bltr.sossoldi.fxwidget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.text.InputType
import android.widget.EditText
import android.widget.TextView

/**
 * Widgets can't host a text field, so this floating bar owns the keyboard while
 * the widget behind it mirrors the digits. Touches outside the bar fall through
 * to the home screen, which is how tapping the widget confirms.
 */
class InputActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var field: EditText
    private lateinit var prefix: TextView
    private var imeSeen = false
    private var ending = false

    private val modeListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == WidgetStore.modeKey(widgetId) &&
            WidgetStore.mode(this, widgetId) != Mode.INPUT
        ) {
            close()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = widgetIdOf(intent)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        skipTransition(open = true)
        setContentView(R.layout.input_sheet)
        window.apply {
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setGravity(Gravity.BOTTOM)
            addFlags(
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            )
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        }

        field = findViewById(R.id.amount)
        prefix = findViewById(R.id.prefix)
        WidgetFlow.begin(this, widgetId)
        bindCurrency()
        field.setText(WidgetStore.digits(this, widgetId))
        field.setSelection(field.length())
        field.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                val digits = s?.toString().orEmpty().replace(',', '.')
                WidgetFlow.type(this@InputActivity, widgetId, digits)
            }
        })
        field.setOnEditorActionListener { _, actionId, event ->
            val enter = event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_UP
            if (actionId == EditorInfo.IME_ACTION_DONE || enter) {
                convert()
                true
            } else {
                false
            }
        }
        findViewById<View>(R.id.convert).setOnClickListener { convert() }

        WidgetStore.listen(this, modeListener)
        RateRefresh.fetchNowIfStale(this)
        closeWhenKeyboardHides()
        field.requestFocus()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val next = widgetIdOf(intent)
        if (next == AppWidgetManager.INVALID_APPWIDGET_ID || next == widgetId) return
        WidgetFlow.commit(this, widgetId)
        widgetId = next
        WidgetFlow.begin(this, widgetId)
        bindCurrency()
        field.setText(WidgetStore.digits(this, widgetId))
        field.setSelection(field.length())
    }

    private fun bindCurrency() {
        val code = WidgetStore.inCode(this, widgetId)
        prefix.text = Currencies.prefix(code).trim()
        field.contentDescription = getString(R.string.amount_hint, Currencies.name(code))
        field.inputType = if (Currencies.fractionDigits(code) > 0) {
            InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
        } else {
            InputType.TYPE_CLASS_NUMBER
        }
    }

    override fun onResume() {
        super.onResume()
        field.post { showKeyboard() }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_OUTSIDE) {
            convert()
            return true
        }
        return super.onTouchEvent(event)
    }

    override fun onStop() {
        super.onStop()
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
            WidgetStore.mode(this, widgetId) == Mode.INPUT
        ) {
            WidgetFlow.commit(this, widgetId)
        }
        if (!isFinishing) close()
    }

    override fun onDestroy() {
        WidgetStore.unlisten(this, modeListener)
        super.onDestroy()
    }

    private fun convert() {
        if (ending) return
        WidgetFlow.commit(this, widgetId)
        close()
    }

    private fun close() {
        ending = true
        if (isFinishing) return
        finish()
        skipTransition(open = false)
    }

    private fun showKeyboard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.show(WindowInsets.Type.ime())
        }
        getSystemService(InputMethodManager::class.java)
            ?.showSoftInput(field, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun closeWhenKeyboardHides() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        window.decorView.setOnApplyWindowInsetsListener { view, insets ->
            if (insets.isVisible(WindowInsets.Type.ime())) {
                imeSeen = true
            } else if (imeSeen) {
                convert()
            }
            view.onApplyWindowInsets(insets)
        }
    }

    @Suppress("DEPRECATION")
    private fun skipTransition(open: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(
                if (open) OVERRIDE_TRANSITION_OPEN else OVERRIDE_TRANSITION_CLOSE,
                0,
                0,
            )
        } else {
            overridePendingTransition(0, 0)
        }
    }

    private fun widgetIdOf(intent: Intent?): Int =
        intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
}
