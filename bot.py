import subprocess, sys

def _install(pkg):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", pkg])

try:
    import discord
except ImportError:
    print("Installation de discord.py...")
    _install("discord.py>=2.3.0")
    import discord

try:
    import requests
except ImportError:
    print("Installation de requests...")
    _install("requests>=2.31.0")
    import requests

"""
TinouHub Discord Bot — panel de controle par joueur.

Setup:
  1. pip install discord.py requests
  2. Cree un Gist avec un fichier "sword_control.json", contenu initial: {}
  3. Cree un token GitHub (scope: gist)
  4. Cree un bot Discord, active "Message Content Intent" + "Server Members Intent"
  5. Remplis BOT_TOKEN, GIST_ID, GITHUB_TOKEN ci-dessous
  6. Mets l'URL raw du Gist dans CONTROL_URL dans le script Lua

Utilisation:
  !control <username_roblox>  →  cree deux messages epingles dans un channel dedie:
                                  1. Panel principal (scanner / farm / ascender / options)
                                  2. Panel profils   (enchants par profil)
"""

import discord
from discord.ext import commands
import requests, json, asyncio, time, logging
import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("bot.log", encoding="utf-8"),
    ]
)
log = logging.getLogger("TinouHub")

# ─── CONFIG ────────────────────────────────────────────────────────────────────
BOT_TOKEN    = config.BOT_TOKEN
GIST_ID      = config.GIST_ID
GITHUB_TOKEN = config.GITHUB_TOKEN
GIST_FILE    = "sword_control.json"
STATE_URL    = f"https://gist.githubusercontent.com/ImTinou/{config.GIST_ID}/raw/sword_state.json"
PREFIX       = "!"
CONTROL_CATEGORY_ID = config.CONTROL_CATEGORY_ID
# ───────────────────────────────────────────────────────────────────────────────

ENCHANTS = [
    "Fortune","Sharpness","Protection","Haste","Swiftness",
    "Critical","Resistance","Healing","Looting","Attraction",
    "Stealth","Ancient","Desperation","Insight","Thorns","Knockback"
]  # "Any" est gere implicitement (slots non remplis = Any)

# ─── STATE ─────────────────────────────────────────────────────────────────────

all_states: dict = {}
# IDs des messages panel pour mise a jour auto: { "Username": {"channel_id": int, "msg_id": int} }
panel_messages: dict = {}

def default_state() -> dict:
    return {
        "id": 0,
        "scanning":  False,
        "farming":   False,
        "ascending": False,
        "auto_bank": True,
        "auto_sell": False,
        "scan_rate": 0.5,
        "profiles": [
            {"active": True,  "slots": ["Any", "Any", "Any"]},
            {"active": False, "slots": ["Any", "Any", "Any"]},
            {"active": False, "slots": ["Any", "Any", "Any"]},
        ],
    }

def get_state(username: str) -> dict:
    if username not in all_states:
        all_states[username] = default_state()
    return all_states[username]

def _push_sync() -> bool:
    r = requests.patch(
        f"https://api.github.com/gists/{GIST_ID}",
        headers={"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"},
        json={"files": {GIST_FILE: {"content": json.dumps(all_states)}}},
    )
    if r.status_code != 200:
        log.error(f"push() failed — HTTP {r.status_code}: {r.text[:200]}")
    return r.status_code == 200

async def push() -> bool:
    return await asyncio.to_thread(_push_sync)

async def update(username: str, changes: dict) -> bool:
    st = get_state(username)
    st.update(changes)
    st["id"] += 1
    log.info(f"[{username}] update -> {changes} (cmd #{st['id']})")
    return await push()

# ─── EMBEDS ────────────────────────────────────────────────────────────────────

def control_embed(username: str) -> discord.Embed:
    st = get_state(username)
    e = discord.Embed(title=f"TinouHub — {username}", color=0x5865F2)
    e.add_field(name="Scanner",   value="🟢 ON" if st["scanning"]  else "🔴 OFF", inline=True)
    e.add_field(name="Farm",      value="🟢 ON" if st["farming"]   else "🔴 OFF", inline=True)
    e.add_field(name="Ascender",  value="🟢 ON" if st["ascending"] else "🔴 OFF", inline=True)
    e.add_field(name="Auto-Bank", value="✅" if st["auto_bank"] else "❌", inline=True)
    e.add_field(name="Auto-Sell", value="✅" if st["auto_sell"] else "❌", inline=True)
    e.add_field(name="Scan Rate", value=f"{st['scan_rate']}s", inline=True)
    e.set_footer(text=f"Cmd #{st['id']} • TinouHub")
    return e

def profiles_embed(username: str) -> discord.Embed:
    st = get_state(username)
    e = discord.Embed(title=f"Profils — {username}", color=0xFEE75C)
    for i, p in enumerate(st["profiles"], 1):
        active_str = "✅ Actif" if p["active"] else "❌ Inactif"
        slots_str  = "  •  ".join(f"`{s}`" for s in p["slots"])
        e.add_field(name=f"Profil {i} — {active_str}", value=slots_str, inline=False)
    e.set_footer(text="Utilise ◀ ▶ pour naviguer entre profils • chaque slot peut avoir le même enchant")
    return e

# ─── PANEL PRINCIPAL ───────────────────────────────────────────────────────────

class ControlView(discord.ui.View):
    def __init__(self, username: str):
        super().__init__(timeout=None)
        self.username = username

    async def update_message(self, interaction: discord.Interaction):
        await interaction.response.edit_message(embed=control_embed(self.username), view=self)

    # Row 0 — Scanner / Farm
    @discord.ui.button(label="▶ Scanner", style=discord.ButtonStyle.green, row=0)
    async def start_scan(self, interaction, _):
        await update(self.username,{"scanning": True})
        await self.update_message(interaction)

    @discord.ui.button(label="⏹ Scanner", style=discord.ButtonStyle.red, row=0)
    async def stop_scan(self, interaction, _):
        await update(self.username,{"scanning": False})
        await self.update_message(interaction)

    @discord.ui.button(label="▶ Farm", style=discord.ButtonStyle.green, row=0)
    async def start_farm(self, interaction, _):
        await update(self.username,{"farming": True})
        await self.update_message(interaction)

    @discord.ui.button(label="⏹ Farm", style=discord.ButtonStyle.red, row=0)
    async def stop_farm(self, interaction, _):
        await update(self.username,{"farming": False})
        await self.update_message(interaction)

    # Row 1 — Ascender / AutoBank / AutoSell
    @discord.ui.button(label="▶ Ascend", style=discord.ButtonStyle.green, row=1)
    async def start_ascend(self, interaction, _):
        await update(self.username,{"ascending": True})
        await self.update_message(interaction)

    @discord.ui.button(label="⏹ Ascend", style=discord.ButtonStyle.red, row=1)
    async def stop_ascend(self, interaction, _):
        await update(self.username,{"ascending": False})
        await self.update_message(interaction)

    @discord.ui.button(label="🏦 AutoBank", style=discord.ButtonStyle.blurple, row=1)
    async def toggle_autobank(self, interaction, _):
        await update(self.username,{"auto_bank": not get_state(self.username)["auto_bank"]})
        await self.update_message(interaction)

    @discord.ui.button(label="💰 AutoSell", style=discord.ButtonStyle.blurple, row=1)
    async def toggle_autosell(self, interaction, _):
        await update(self.username,{"auto_sell": not get_state(self.username)["auto_sell"]})
        await self.update_message(interaction)

    # Row 2 — Scan rate
    @discord.ui.button(label="⬅ Scan -0.1s", style=discord.ButtonStyle.grey, row=2)
    async def scan_down(self, interaction, _):
        st = get_state(self.username)
        await update(self.username,{"scan_rate": round(max(0.1, st["scan_rate"] - 0.1), 1)})
        await self.update_message(interaction)

    @discord.ui.button(label="Scan +0.1s ➡", style=discord.ButtonStyle.grey, row=2)
    async def scan_up(self, interaction, _):
        st = get_state(self.username)
        await update(self.username,{"scan_rate": round(min(3.0, st["scan_rate"] + 0.1), 1)})
        await self.update_message(interaction)

# ─── PANEL PROFILS ─────────────────────────────────────────────────────────────

class SlotSelect(discord.ui.Select):
    """Select pour un slot unique d'un profil (permet le même enchant sur plusieurs slots)."""

    def __init__(self, username: str, prof_idx: int, slot_idx: int, row: int):
        self.username  = username
        self.prof_idx  = prof_idx
        self.slot_idx  = slot_idx

        current = get_state(username)["profiles"][prof_idx]["slots"][slot_idx]
        options = [
            discord.SelectOption(label=e, value=e, default=(e == current))
            for e in ["Any"] + ENCHANTS
        ]

        super().__init__(
            placeholder=f"Profil {prof_idx + 1} · Slot {slot_idx + 1}",
            options=options,
            min_values=1,
            max_values=1,
            row=row,
        )

    async def callback(self, interaction: discord.Interaction):
        st = get_state(self.username)
        st["profiles"][self.prof_idx]["slots"][self.slot_idx] = self.values[0]
        st["id"] += 1
        log.info(f"[{self.username}] profil {self.prof_idx+1} slot {self.slot_idx+1} -> {self.values[0]}")
        await push()
        new_view = ProfilesView(self.username)
        await interaction.response.edit_message(
            embed=profiles_embed(self.username), view=new_view
        )


class ProfileToggle(discord.ui.Button):
    """Bouton ON/OFF pour activer/desactiver un profil."""

    def __init__(self, username: str, prof_idx: int):
        self.username  = username
        self.prof_idx  = prof_idx
        active = get_state(username)["profiles"][prof_idx]["active"]
        super().__init__(
            label=f"Profil {prof_idx + 1}  {'✅' if active else '❌'}",
            style=discord.ButtonStyle.green if active else discord.ButtonStyle.red,
            row=3,
        )

    async def callback(self, interaction: discord.Interaction):
        st = get_state(self.username)
        st["profiles"][self.prof_idx]["active"] = not st["profiles"][self.prof_idx]["active"]
        st["id"] += 1
        await push()
        new_view = ProfilesView(self.username)
        await interaction.response.edit_message(
            embed=profiles_embed(self.username), view=new_view
        )


class ProfilesView(discord.ui.View):
    """Vue paginée : un profil à la fois, 3 slot-selects + toggle + nav."""

    def __init__(self, username: str, prof_idx: int = 0):
        super().__init__(timeout=None)
        self.username = username
        self.prof_idx = prof_idx
        for slot in range(3):
            self.add_item(SlotSelect(username, prof_idx, slot, row=slot))   # rows 0-2
        self.add_item(ProfileToggle(username, prof_idx))                    # row 3

    @discord.ui.button(label="◀ Profil préc.", style=discord.ButtonStyle.grey, row=4)
    async def prev_profile(self, interaction: discord.Interaction, _):
        new_idx = (self.prof_idx - 1) % 3
        await interaction.response.edit_message(
            embed=profiles_embed(self.username),
            view=ProfilesView(self.username, new_idx)
        )

    @discord.ui.button(label="Profil suiv. ▶", style=discord.ButtonStyle.grey, row=4)
    async def next_profile(self, interaction: discord.Interaction, _):
        new_idx = (self.prof_idx + 1) % 3
        await interaction.response.edit_message(
            embed=profiles_embed(self.username),
            view=ProfilesView(self.username, new_idx)
        )

# ─── BOT ───────────────────────────────────────────────────────────────────────

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents)

# ─── HELPER : creation du channel control ──────────────────────────────────────

async def create_control_channel(guild: discord.Guild, username: str, member: discord.Member = None) -> discord.TextChannel | None:
    """Cree #control-<username> avec les deux panels. Retourne None si deja existant."""
    channel_name = f"control-{username.lower()}"
    if discord.utils.get(guild.channels, name=channel_name):
        return None

    category = guild.get_channel(CONTROL_CATEGORY_ID) if CONTROL_CATEGORY_ID else None

    # Permissions : personne ne voit le channel sauf le membre concerne + le bot
    overwrites = {
        guild.default_role: discord.PermissionOverwrite(view_channel=False),
        guild.me:           discord.PermissionOverwrite(view_channel=True, send_messages=True, manage_messages=True),
    }
    if member:
        overwrites[member] = discord.PermissionOverwrite(view_channel=True, send_messages=False)

    channel = await guild.create_text_channel(channel_name, category=category, overwrites=overwrites)

    msg1 = await channel.send(
        content="**Panel de contrôle**",
        embed=control_embed(username),
        view=ControlView(username),
    )
    msg2 = await channel.send(
        content="**Profils d'enchants**",
        embed=profiles_embed(username),
        view=ProfilesView(username),
    )
    try:
        await msg2.pin()
        await msg1.pin()
    except: pass

    # Stocke les IDs pour la sync automatique
    panel_messages[username] = {"channel_id": channel.id, "msg_id": msg1.id}

    return channel

# ─── SETUP : modal + bouton + commande !config ─────────────────────────────────

class UsernameModal(discord.ui.Modal, title="Ouvrir mon panel TinouHub"):
    username = discord.ui.TextInput(
        label="Ton username Roblox",
        placeholder="ex: ImTinou",
        min_length=3,
        max_length=20,
    )

    async def on_submit(self, interaction: discord.Interaction):
        username = self.username.value.strip()
        await interaction.response.defer(ephemeral=True)

        channel = await create_control_channel(interaction.guild, username, interaction.user)
        if channel is None:
            existing = discord.utils.get(interaction.guild.channels, name=f"control-{username.lower()}")
            await interaction.followup.send(
                f"Tu as déjà un panel : {existing.mention}", ephemeral=True
            )
        else:
            await interaction.followup.send(
                f"✅ Panel créé : {channel.mention}", ephemeral=True
            )


class SetupView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(
        label="🎮  Ouvrir mon panel de contrôle",
        style=discord.ButtonStyle.blurple,
    )
    async def open_panel(self, interaction: discord.Interaction, _):
        await interaction.response.send_modal(UsernameModal())


@bot.command(name="config")
async def cmd_config(ctx):
    """Cree le channel de setup avec le bouton d'inscription. Ex: !config"""
    channel_name = "tinouhub-setup"

    existing = discord.utils.get(ctx.guild.channels, name=channel_name)
    if existing:
        await ctx.send(f"Channel déjà existant : {existing.mention}", delete_after=8)
        try: await ctx.message.delete(delay=8)
        except: pass
        return

    category = ctx.guild.get_channel(CONTROL_CATEGORY_ID) if CONTROL_CATEGORY_ID else None
    channel  = await ctx.guild.create_text_channel(channel_name, category=category)

    e = discord.Embed(
        title="TinouHub — Sword Factory X",
        description=(
            "Clique sur le bouton ci-dessous pour créer ton panel de contrôle personnel.\n\n"
            "Il te sera demandé ton **username Roblox** — "
            "un channel privé sera créé avec tous tes boutons de contrôle."
        ),
        color=0x5865F2,
    )
    e.set_footer(text="TinouHub • Un panel par joueur")

    msg = await channel.send(embed=e, view=SetupView())
    try: await msg.pin()
    except: pass

    await ctx.send(f"✅ Channel setup créé : {channel.mention}", delete_after=8)
    try: await ctx.message.delete(delay=8)
    except: pass

@bot.command(name="control")
async def cmd_control(ctx, username: str):
    """Cree un channel de controle manuellement. Ex: !control ImTinou"""
    channel = await create_control_channel(ctx.guild, username)
    if channel is None:
        existing = discord.utils.get(ctx.guild.channels, name=f"control-{username.lower()}")
        await ctx.send(f"Channel déjà existant : {existing.mention}", delete_after=8)
    else:
        await ctx.send(f"✅ Channel créé : {channel.mention}", delete_after=8)
    try: await ctx.message.delete(delay=8)
    except: pass

@bot.command(name="delcontrol")
async def cmd_delcontrol(ctx, username: str):
    """Supprime le channel de controle d'un joueur. Ex: !delcontrol ImTinou"""
    channel_name = f"control-{username.lower()}"
    channel = discord.utils.get(ctx.guild.channels, name=channel_name)
    if not channel:
        await ctx.send("Channel introuvable.", delete_after=5)
        return
    await channel.delete()
    await ctx.send(f"🗑️ `{channel_name}` supprimé.", delete_after=5)
    try: await ctx.message.delete(delay=5)
    except: pass

async def fetch_game_state() -> dict:
    """Recupere l'etat in-game depuis le Gist."""
    def _get():
        for attempt in range(3):
            try:
                return requests.get(
                    f"https://api.github.com/gists/{GIST_ID}",
                    headers={"Authorization": f"token {GITHUB_TOKEN}", "Cache-Control": "no-cache"},
                    timeout=15,
                )
            except requests.exceptions.Timeout:
                if attempt == 2:
                    raise
                time.sleep(2)
    try:
        r = await asyncio.to_thread(_get)
    except Exception:
        return {}
    if r.status_code != 200:
        return {}
    try:
        content = r.json()["files"]["sword_state.json"]["content"]
        return json.loads(content)
    except Exception:
        return {}

async def sync_game_to_discord():
    """Boucle qui lit l'etat in-game et met a jour les panels Discord toutes les 60s."""
    await bot.wait_until_ready()
    while not bot.is_closed():
        await asyncio.sleep(60)
        try:
            game_state = await fetch_game_state()
            for username, state in game_state.items():
                if username not in panel_messages:
                    continue
                # Mise a jour du state en memoire (sans ecraser le control id)
                if username in all_states:
                    # Seulement les états temps réel — PAS les settings/profiles
                    # (ceux-ci sont contrôlés depuis Discord et ne doivent pas être écrasés)
                    for k in ("scanning", "farming", "ascending"):
                        if k in state:
                            all_states[username][k] = state[k]
                else:
                    all_states[username] = default_state()
                    # Premier chargement : on prend tout sauf on garde id=0
                    for k in ("scanning","farming","ascending","auto_bank","auto_sell","scan_rate","profiles"):
                        if k in state:
                            all_states[username][k] = state[k]

                # Mise a jour du message panel Discord
                info = panel_messages[username]
                for guild in bot.guilds:
                    channel = guild.get_channel(info["channel_id"])
                    if not channel:
                        continue
                    try:
                        msg = await channel.fetch_message(info["msg_id"])
                        await msg.edit(embed=control_embed(username))
                    except Exception:
                        pass
        except Exception as e:
            log.error(f"sync_game_to_discord error: {e}")

async def restore_panels():
    """Au démarrage : retrouve les channels control-* et leurs messages pinned."""
    await bot.wait_until_ready()

    # Charger l'état depuis le Gist control
    try:
        def _read():
            return requests.get(
                f"https://api.github.com/gists/{GIST_ID}",
                headers={"Authorization": f"token {GITHUB_TOKEN}", "Cache-Control": "no-cache"}, timeout=15
            )
        r = await asyncio.to_thread(_read)
        if r.status_code == 200:
            content = r.json()["files"][GIST_FILE]["content"]
            data = json.loads(content)
            for username, state in data.items():
                all_states[username] = state
            log.info(f"État chargé depuis Gist : {list(data.keys())}")
    except Exception as e:
        log.error(f"restore_panels: lecture Gist échouée: {e}")

    # Retrouver les messages panels dans les channels control-*
    for guild in bot.guilds:
        for channel in guild.text_channels:
            if not channel.name.startswith("control-"):
                continue
            username = channel.name[len("control-"):]
            # Chercher le username exact (casse) dans all_states
            real_username = next((u for u in all_states if u.lower() == username), username)
            try:
                pins = [m async for m in channel.pins()]
                if pins:
                    _main_msg = pins[-1]  # noqa
                    # Re-envoyer les messages avec les vues fraîches (plus fiable que add_view)
                    new_main = await channel.send(
                        content="**Panel de contrôle**",
                        embed=control_embed(real_username),
                        view=ControlView(real_username),
                    )
                    panel_messages[real_username] = {
                        "channel_id": channel.id,
                        "msg_id": new_main.id,
                    }
                    await channel.send(
                        content="**Profils d'enchants**",
                        embed=profiles_embed(real_username),
                        view=ProfilesView(real_username),
                    )
                    # Supprimer les anciens messages
                    try:
                        for old_pin in pins:
                            await old_pin.unpin()
                            await old_pin.delete()
                    except Exception:
                        pass
                    try:
                        await new_main.pin()
                    except Exception:
                        pass
                    log.info(f"Panel restauré : {real_username} -> #{channel.name}")
            except Exception as e:
                log.error(f"restore_panels {channel.name}: {e}")

@bot.event
async def on_ready():
    log.info(f"Bot connecté : {bot.user}")
    log.info(f"Gist ID      : {GIST_ID}")
    bot.loop.create_task(restore_panels())
    bot.loop.create_task(sync_game_to_discord())

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingRequiredArgument):
        await ctx.send("Usage : `!control <username_roblox>`", delete_after=8)
    elif isinstance(error, commands.CommandNotFound):
        pass
    else:
        log.error(f"Erreur commande '{ctx.command}': {error}")

bot.run(BOT_TOKEN)
