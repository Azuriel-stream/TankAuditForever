local ADDON_NAME, TAU = ...

-- Group chat requests (one picked at random). %s = spell link.
TAU.Data.REQUESTS = {
    FORTITUDE = {
        "Priest, could you bolster my health with %s?",
        "My shield is strong, but my health is low. %s please!",
        "Fortify me, Priest! I could use %s.",
    },
    SPIRIT = {
        "I need the guidance of the %s.",
        "Priest, if you can spare the mana, %s please!",
        "My spirit is willing, but the buff is missing. %s please.",
    },
    MARK_OF_THE_WILD = {
        "Druid, grant me the %s if you can!",
        "The spirits whisper... I need %s!",
        "My fur needs thickening. %s please!",
    },
    THORNS = {
        "Druid, a layer of %s would help with threat.",
        "I could use %s to make them pay for striking me!",
        "Let them bleed when they strike. %s please!",
    },
    ARCANE_INTELLECT = {
        "Mage, I need some brilliance! %s please!",
        "My mind feels dull. %s, if you please!",
        "Grant me the intellect to hold this aggro! (%s)",
    },
    BATTLE_SHOUT = {
        "Warrior, let me hear your %s!",
        "Roar for glory! I need %s!",
        "Strengthen our arms, Warrior! %s please!",
    },
    KINGS = {
        "Paladin, grant me the majesty of %s!",
        "A tank is nothing without a crown. %s please!",
        "A touch of royalty would help, Paladin. %s please!",
    },
    MIGHT = {
        "Paladin, grant me the strength to crush my foes! %s!",
        "My swings are weak. I need %s!",
        "Empower me, Paladin! %s!",
    },
    WISDOM = {
        "Paladin, my mana is draining fast. %s please!",
        "Grant me the clarity of the Light. %s!",
        "I need mana to hold the line! %s please!",
    },
    LIGHT = {
        "Illumine my path and my healing! %s!",
        "Let the healers' light shine brighter on me! %s!",
        "I need the holy light to mend me faster. %s please!",
    },
    PALADIN_AURA = {
        "Paladin, I need an Aura (%s)!",
        "My armor needs boosting! %s please!",
        "We are missing an Aura, Paladin! (%s)",
    },
    DEFAULT = {
        "I could use %s!",
        "Can I get %s please?",
        "Buff %s please!",
    },
}

-- Whispered to the caster. %s = spell link, %s = caster's first name.
TAU.Data.THANKS = {
    "Thanks for the %s, %s!",
    "Got the %s - thank you, %s!",
    "Much appreciated, %s received. Thanks %s!",
}
