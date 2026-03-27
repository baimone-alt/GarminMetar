import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Communications;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

// --- 1. ENTRY POINT ---
class MetarTafApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        var lastIcao = Storage.getValue("last_icao");
        // Se non c'è nulla salvato, propone LIML di default
        if (lastIcao == null || lastIcao.equals("")) {
            return [ new IcaoInputView(), new IcaoInputDelegate() ];
        }
        return [ new DataView(lastIcao, "metar"), new DataDelegate(lastIcao, "metar") ];
    }
}

// --- 2. VISTA DATI (METAR/TAF) ---
class DataView extends WatchUi.View {
    var _icao, _type, _message = "Caricamento...";
    var _timestamp = "";
    var _scrollY = 0;
    var _apiKey = "IfkDhnmLPwGstSV-IoAIw3GX53zmRlUWH3FlFBuHRyc";

    function initialize(icao, type) {
        View.initialize();
        _icao = icao;
        _type = type;
    }

    function onShow() {
        var url = "https://avwx.rest/api/" + _type + "/" + _icao;
        var options = {
            :method => Communications.HTTP_METHOD_GET,
            :headers => { "Authorization" => _apiKey }
        };
        Communications.makeWebRequest(url, null, options, method(:onReceive));
    }

    function onReceive(responseCode, data) {
        if (responseCode == 200) {
            _message = data["raw"];
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            _timestamp = Lang.format("$1$/$2$ $3$:$4$", [
                now.day.format("%02d"),
                now.month.format("%02d"),
                now.hour.format("%02d"),
                now.min.format("%02d")
            ]);
        } else {
            _message = "Errore: " + responseCode + "\nControlla connessione.";
            _timestamp = "";
        }
        WatchUi.requestUpdate();
    }

    function scroll(delta) {
        _scrollY += delta;
        if (_scrollY > 0) { _scrollY = 0; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
       
        // AREA TESTO (NO HEADER, FONT MEDIUM)
        var fullText = _message + "\n\n" + _timestamp;
        var textArea = new WatchUi.TextArea({
            :text => fullText,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_MEDIUM,
            :locX => 10,
            :locY => 15 + _scrollY,
            :width => dc.getWidth() - 20,
            :height => 2000,
            :justification => Graphics.TEXT_JUSTIFY_LEFT
        });
        textArea.draw(dc);

        // FOOTER FISSO (ORANGE BOLD)
        var footerHeight = 45;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, dc.getHeight() - footerHeight, dc.getWidth(), footerHeight);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dc.getHeight() - footerHeight, dc.getWidth(), dc.getHeight() - footerHeight);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, dc.getHeight() - 38, Graphics.FONT_MEDIUM, _type.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// --- 3. DELEGATE NAVIGAZIONE ---
class DataDelegate extends WatchUi.BehaviorDelegate {
    var _icao, _type;
    function initialize(icao, type) {
        BehaviorDelegate.initialize();
        _icao = icao;
        _type = type;
    }
    function onPreviousPage() { WatchUi.getCurrentView()[0].scroll(60); return true; }
    function onNextPage() { WatchUi.getCurrentView()[0].scroll(-60); return true; }
    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_LEFT || dir == WatchUi.SWIPE_RIGHT) {
            var nextType = _type.equals("metar") ? "taf" : "metar";
            WatchUi.switchToView(new DataView(_icao, nextType), new DataDelegate(_icao, nextType), WatchUi.SLIDE_LEFT);
            return true;
        }
        return false;
    }
    function onSelect() {
        WatchUi.pushView(new IcaoInputView(), new IcaoInputDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

// --- 4. SELEZIONE ICAO (DEFAULT LIML) ---
class IcaoInputView extends WatchUi.View {
    // Modificato qui: LIML di default
    var letters = ["L", "I", "M", "L"];
    var cursor = 0;
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, 20, Graphics.FONT_SMALL, "SET ICAO:", Graphics.TEXT_JUSTIFY_CENTER);
        var str = letters[0] + letters[1] + letters[2] + letters[3];
        dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_NUMBER_MEDIUM, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, dc.getHeight() - 40, Graphics.FONT_XTINY, "POSIZIONE: " + (cursor + 1), Graphics.TEXT_JUSTIFY_CENTER);
    }
    function changeLetter(dir) {
        var charCode = letters[cursor].toChar().toNumber() + dir;
        if (charCode < 65) { charCode = 90; }
        if (charCode > 90) { charCode = 65; }
        letters[cursor] = charCode.toChar().toString();
        WatchUi.requestUpdate();
    }
}

class IcaoInputDelegate extends WatchUi.BehaviorDelegate {
    function onNextKey() { WatchUi.getCurrentView()[0].changeLetter(-1); return true; }
    function onPreviousKey() { WatchUi.getCurrentView()[0].changeLetter(1); return true; }
    function onSelect() {
        var view = WatchUi.getCurrentView()[0];
        if (view.cursor < 3) {
            view.cursor++;
            WatchUi.requestUpdate();
        } else {
            var finalIcao = view.letters[0] + view.letters[1] + view.letters[2] + view.letters[3];
            Storage.setValue("last_icao", finalIcao);
            WatchUi.switchToView(new DataView(finalIcao, "metar"), new DataDelegate(finalIcao, "metar"), WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}
