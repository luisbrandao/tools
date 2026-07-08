/* ntfy-indicator — indicador de painel para tópicos ntfy
 *
 * Config: ~/.config/ntfy-indicator.json
 * {
 *   "server": "https://ntfy.example.com",
 *   "token": "tk_XXXXXXXX",
 *   "topics": ["meu-topico"],
 *   "poll_seconds": 30,
 *   "history_hours": 12
 * }
 *
 * GNOME Shell 40–44 (old-style extension, Soup 2.4)
 */

'use strict';

imports.gi.versions.Soup = '2.4';
const { GObject, St, Clutter, GLib } = imports.gi;
const Soup = imports.gi.Soup;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const ByteArray = imports.byteArray;

const MAX_MESSAGES = 15;
const MAX_SEEN_IDS = 300;
const CONFIG_PATH = GLib.get_user_config_dir() + '/ntfy-indicator.json';
const STATE_PATH = GLib.get_user_cache_dir() + '/ntfy-indicator-state.json';

const NtfyIndicator = GObject.registerClass(
class NtfyIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Ntfy Indicator');

        this._messages = [];   // mais recente primeiro
        this._unread = 0;
        this._since = null;
        this._seen = new Set(); // ids já processados — "limpar" é permanente
        this._timeoutId = 0;
        this._lastStatus = 'Ainda não checou';
        this._session = new Soup.Session({ timeout: 20 });

        const box = new St.BoxLayout({ style_class: 'panel-status-menu-box' });
        this._icon = new St.Icon({
            icon_name: 'preferences-system-notifications-symbolic',
            style_class: 'system-status-icon',
        });
        this._countLabel = new St.Label({
            text: '',
            y_align: Clutter.ActorAlign.CENTER,
            style: 'font-weight: bold; padding-left: 2px;',
        });
        box.add_child(this._icon);
        box.add_child(this._countLabel);
        this.add_child(box);

        this._config = this._loadConfig();

        // abrir o menu marca tudo como lido
        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open) {
                this._unread = 0;
                this._updateBadge();
                this._rebuildMenu();
                this._saveState();
            }
        });

        this._rebuildMenu();

        if (this._config) {
            const restored = this._loadState();
            if (!restored) {
                const hours = this._config.history_hours ?? 12;
                this._since = Math.floor(GLib.get_real_time() / 1e6) - hours * 3600;
            }
            // com estado restaurado, mensagens novas desde o último run notificam
            this._fetch(!restored);
            const poll = this._config.poll_seconds ?? 30;
            this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, poll, () => {
                this._fetch(false);
                return GLib.SOURCE_CONTINUE;
            });
        }
    }

    _loadConfig() {
        try {
            const [ok, contents] = GLib.file_get_contents(CONFIG_PATH);
            if (!ok)
                return null;
            const cfg = JSON.parse(ByteArray.toString(contents));
            if (!cfg.server || !cfg.topics || !cfg.topics.length) {
                this._lastStatus = 'Config sem "server"/"topics"';
                return null;
            }
            return cfg;
        } catch (e) {
            this._lastStatus = `Erro na config: ${e.message}`;
            return null;
        }
    }

    _loadState() {
        try {
            const [ok, contents] = GLib.file_get_contents(STATE_PATH);
            if (!ok)
                return false;
            const st = JSON.parse(ByteArray.toString(contents));
            if (!st.since)
                return false;
            this._since = st.since;
            this._seen = new Set(st.seen || []);
            this._messages = st.messages || [];
            this._unread = st.unread || 0;
            return true;
        } catch (e) {
            return false; // sem estado (primeiro run) ou corrompido — recomeça
        }
    }

    _saveState() {
        try {
            GLib.file_set_contents(STATE_PATH, JSON.stringify({
                since: this._since,
                seen: [...this._seen].slice(-MAX_SEEN_IDS),
                messages: this._messages,
                unread: this._unread,
            }));
        } catch (e) {
            log(`ntfy-indicator: falha ao salvar estado (${e.message})`);
        }
    }

    _fetch(initial) {
        const url = `${this._config.server}/${this._config.topics.join(',')}/json?poll=1&since=${this._since}`;
        const msg = Soup.Message.new('GET', url);
        if (!msg) {
            this._lastStatus = 'URL inválida na config';
            this._rebuildMenu();
            return;
        }
        if (this._config.token)
            msg.request_headers.append('Authorization', `Bearer ${this._config.token}`);

        this._session.queue_message(msg, (_session, m) => {
            if (m.status_code !== 200) {
                this._lastStatus = `Erro HTTP ${m.status_code}`;
                this._updateBadge();
                this._rebuildMenu();
                return;
            }

            const fresh = [];
            for (const line of (m.response_body.data || '').split('\n')) {
                if (!line.trim())
                    continue;
                try {
                    const ev = JSON.parse(line);
                    if (ev.event === 'message' && !this._seen.has(ev.id))
                        fresh.push(ev);
                } catch (e) {
                    log(`ntfy-indicator: linha não-JSON ignorada (${e.message})`);
                }
            }

            if (fresh.length) {
                for (const ev of fresh) {
                    this._seen.add(ev.id);
                    // ponteiro em timestamp: seguro com múltiplos tópicos;
                    // repetições na borda são filtradas pelo dedupe de ids
                    this._since = Math.max(this._since, ev.time);
                }
                for (const ev of [...fresh].reverse())
                    this._messages.unshift(ev);
                this._messages.length = Math.min(this._messages.length, MAX_MESSAGES);

                if (!initial) {
                    this._unread += fresh.length;
                    for (const ev of fresh.slice(-3))
                        Main.notify(this._msgTitle(ev), ev.message || '');
                    if (fresh.length > 3)
                        Main.notify('ntfy', `… e mais ${fresh.length - 3} mensagens`);
                }
                this._saveState();
            }

            const now = GLib.DateTime.new_now_local().format('%H:%M');
            this._lastStatus = `OK — checado às ${now}`;
            this._updateBadge();
            this._rebuildMenu();
        });
    }

    _msgTitle(ev) {
        const prio = (ev.priority ?? 3) >= 4 ? '⚠ ' : '';
        return `${prio}${ev.title || ev.topic}`;
    }

    _updateBadge() {
        this._countLabel.text = this._unread > 0 ? `${this._unread}` : '';
        this._icon.icon_name = this._lastStatus.startsWith('OK') || this._lastStatus.startsWith('Ainda')
            ? 'preferences-system-notifications-symbolic'
            : 'network-error-symbolic';
    }

    _rebuildMenu() {
        this.menu.removeAll();

        const status = this._config
            ? `${this._config.topics.join(', ')} — ${this._lastStatus}`
            : `Crie ${CONFIG_PATH} — ${this._lastStatus}`;
        const statusItem = new PopupMenu.PopupMenuItem(status, { reactive: false });
        statusItem.label.style = 'font-size: 0.85em; color: #999;';
        this.menu.addMenuItem(statusItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (!this._messages.length) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem('Sem mensagens', { reactive: false }));
        }

        for (const ev of this._messages) {
            const when = GLib.DateTime.new_from_unix_local(ev.time).format('%d/%m %H:%M');
            const item = new PopupMenu.PopupMenuItem(
                `${when}  ${this._msgTitle(ev)}\n${ev.message || ''}`,
                { reactive: false });
            item.label.clutter_text.set_line_wrap(true);
            item.label.style = 'max-width: 30em;';
            this.menu.addMenuItem(item);
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const refresh = new PopupMenu.PopupMenuItem('Atualizar agora');
        refresh.connect('activate', () => {
            if (this._config)
                this._fetch(false);
        });
        this.menu.addMenuItem(refresh);

        const clear = new PopupMenu.PopupMenuItem('Limpar mensagens');
        clear.connect('activate', () => {
            this._messages = [];
            this._unread = 0;
            this._saveState(); // permanente: não volta em reload/reboot
            this._updateBadge();
            this._rebuildMenu();
        });
        this.menu.addMenuItem(clear);
    }

    destroy() {
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        this._session.abort();
        super.destroy();
    }
});

let indicator = null;

function init() {
}

function enable() {
    indicator = new NtfyIndicator();
    Main.panel.addToStatusArea('ntfy-indicator', indicator);
}

function disable() {
    if (indicator) {
        indicator.destroy();
        indicator = null;
    }
}
