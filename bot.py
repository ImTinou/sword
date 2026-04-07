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
import requests, json
import config

# ─── CONFIG ────────────────────────────────────────────────────────────────────
BOT_TOKEN    = config.BOT_TOKEN
GIST_ID      = config.GIST_ID
GITHUB_TOKEN = config.GITHUB_TOKEN
GIST_FILE    = "sword_control.json"
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

def push() -> bool:
    r = requests.patch(
        f"https://api.github.com/gists/{GIST_ID}",
        headers={
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github.v3+json",
        },
        json={"files": {GIST_FILE: {"content": json.dumps(all_states)}}},
    )
    return r.status_code == 200

def update(username: str, changes: dict) -> bool:
    st = get_state(username)
    st.update(changes)
    st["id"] += 1
    return push()

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
    e.set_footer(text="Selectionne 1 a 3 enchants par profil • vide = Any Any Any")
    return e

# ─── PANEL PRINCIPAL ───────────────────────────────────────────────────────────

class ControlView(discord.ui.View):
    def __init__(self, username: str):
        super().__init__(timeout=None)
        self.username = username

    async def _refresh(self, interaction: discord.Interaction):
        await interaction.response.edit_message(embed=control_embed(self.username), view=self)

    # Row 0 — Scanner / Farm
    @discord.ui.button(label="▶ Scanner", style=discord.ButtonStyle.green, row=0)
    async def start_scan(self, interaction, _):
        update(self.username, {"scanning": True})
        await self._refresh(interaction)

    @discord.ui.button(label="⏹ Scanner", style=discord.ButtonStyle.red, row=0)
    async def stop_scan(self, interaction, _):
        update(self.username, {"scanning": False})
        await self._refresh(interaction)

    @discord.ui.button(label="▶ Farm", style=discord.ButtonStyle.green, row=0)
    async def start_farm(self, interaction, _):
        update(self.username, {"farming": True})
        await self._refresh(interaction)

    @discord.ui.button(label="⏹ Farm", style=discord.ButtonStyle.red, row=0)
    async def stop_farm(self, interaction, _):
        update(self.username, {"farming": False})
        await self._refresh(interaction)

    # Row 1 — Ascender / AutoBank / AutoSell
    @discord.ui.button(label="▶ Ascend", style=discord.ButtonStyle.green, row=1)
    async def start_ascend(self, interaction, _):
        update(self.username, {"ascending": True})
        await self._refresh(interaction)

    @discord.ui.button(label="⏹ Ascend", style=discord.ButtonStyle.red, row=1)
    async def stop_ascend(self, interaction, _):
        update(self.username, {"ascending": False})
        await self._refresh(interaction)

    @discord.ui.button(label="🏦 AutoBank", style=discord.ButtonStyle.blurple, row=1)
    async def toggle_autobank(self, interaction, _):
        update(self.username, {"auto_bank": not get_state(self.username)["auto_bank"]})
        await self._refresh(interaction)

    @discord.ui.button(label="💰 AutoSell", style=discord.ButtonStyle.blurple, row=1)
    async def toggle_autosell(self, interaction, _):
        update(self.username, {"auto_sell": not get_state(self.username)["auto_sell"]})
        await self._refresh(interaction)

    # Row 2 — Scan rate
    @discord.ui.button(label="⬅ Scan -0.1s", style=discord.ButtonStyle.grey, row=2)
    async def scan_down(self, interaction, _):
        st = get_state(self.username)
        update(self.username, {"scan_rate": round(max(0.1, st["scan_rate"] - 0.1), 1)})
        await self._refresh(interaction)

    @discord.ui.button(label="Scan +0.1s ➡", style=discord.ButtonStyle.grey, row=2)
    async def scan_up(self, interaction, _):
        st = get_state(self.username)
        update(self.username, {"scan_rate": round(min(3.0, st["scan_rate"] + 0.1), 1)})
        await self._refresh(interaction)

# ─── PANEL PROFILS ─────────────────────────────────────────────────────────────

class EnchantSelect(discord.ui.Select):
    """Menu deroulant multi-selection pour les enchants d'un profil."""

    def __init__(self, username: str, prof_idx: int):
        self.username  = username
        self.prof_idx  = prof_idx

        # Options = tous les enchants (hors Any)
        # On marque en default les enchants actuellement selectionnes
        current = [
            s for s in get_state(username)["profiles"][prof_idx]["slots"]
            if s != "Any"
        ]
        options = [
            discord.SelectOption(label=e, value=e, default=(e in current))
            for e in ENCHANTS
        ]

        super().__init__(
            placeholder=f"Profil {prof_idx + 1} — enchants voulus (vide = Any)",
            options=options,
            min_values=0,
            max_values=3,
            row=prof_idx,
        )

    async def callback(self, interaction: discord.Interaction):
        st = get_state(self.username)
        # Slots = valeurs choisies, complet a 3 avec "Any"
        slots = list(self.values)
        while len(slots) < 3:
            slots.append("Any")
        st["profiles"][self.prof_idx]["slots"] = slots
        st["id"] += 1
        push()
        # Reconstruction de la vue pour mettre a jour les defaults
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
        push()
        new_view = ProfilesView(self.username)
        await interaction.response.edit_message(
            embed=profiles_embed(self.username), view=new_view
        )


class ProfilesView(discord.ui.View):
    """Vue complete : 3 selects d'enchants + 3 boutons activer/desactiver."""

    def __init__(self, username: str):
        super().__init__(timeout=None)
        for i in range(3):
            self.add_item(EnchantSelect(username, i))   # rows 0-2
            self.add_item(ProfileToggle(username, i))   # row 3

# ─── BOT ───────────────────────────────────────────────────────────────────────

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents)

@bot.command(name="control")
async def cmd_control(ctx, username: str):
    """Cree un channel de controle pour un joueur Roblox. Ex: !control ImTinou"""
    channel_name = f"control-{username.lower()}"

    existing = discord.utils.get(ctx.guild.channels, name=channel_name)
    if existing:
        await ctx.send(f"Channel déjà existant : {existing.mention}", delete_after=8)
        try: await ctx.message.delete(delay=8)
        except: pass
        return

    category = ctx.guild.get_channel(CONTROL_CATEGORY_ID) if CONTROL_CATEGORY_ID else None
    channel  = await ctx.guild.create_text_channel(channel_name, category=category)

    # Message 1 — panel principal
    msg1 = await channel.send(
        content="**Panel de contrôle**",
        embed=control_embed(username),
        view=ControlView(username),
    )

    # Message 2 — profils enchants
    msg2 = await channel.send(
        content="**Profils d'enchants**",
        embed=profiles_embed(username),
        view=ProfilesView(username),
    )

    try:
        await msg2.pin()
        await msg1.pin()  # pin dans l'ordre inverse → msg1 apparait en haut
    except: pass

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

@bot.event
async def on_ready():
    print(f"Bot connecté : {bot.user}")
    print(f"Gist ID      : {GIST_ID}")

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingRequiredArgument):
        await ctx.send("Usage : `!control <username_roblox>`", delete_after=8)
    elif isinstance(error, commands.CommandNotFound):
        pass

bot.run(BOT_TOKEN)
