<template>
  <v-btn-toggle v-model="internalLanguage" mandatory>
    <v-btn
      value="ja"
      active-class="error white--text elevation-4"
    >
      JA
    </v-btn>

    <v-btn
      value="en"
      active-class="info white--text elevation-4"
    >
      EN
    </v-btn>
  </v-btn-toggle>
</template>
<script>
export default {
  name: 'SwitchLanguageButtons',
  model: {
    prop: 'value',
    event: 'change',
  },
  props: {
    language: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      internalLanguage: this.language,
    }
  },
  computed: {
  },
  watch: {
    value(value) {
      this.internalLanguage = value
    },
    internalLanguage(value) {
      this.$emit('change', value)
    },
  },
}
</script>
