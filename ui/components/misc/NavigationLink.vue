<template>
  <v-btn
    :to="to"
    :disabled="isNotLoggedIn && !always"
    nuxt
    text
    tile
    height="100%"
    class="black--text px-0"
    :active-class="activeClass"
    @click="$emit('click')"
  >
    <slot />
  </v-btn>
</template>
<script>
export default {
  name: 'NavigationLink',
  props: {
    to: {
      type: String,
      required: true,
    },
    always: {
      type: Boolean,
      default: false,
    },
    activeClass: {
      type: String,
      default: 'secondary darken-1',
    },
  },
}
</script>
