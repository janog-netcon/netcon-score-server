export default {
  // ---- Nuxt標準の設定 ----
  ssr: false,
  server: {
    host: '0.0.0.0',
  },
  htmlAttrs: {
    lang: 'ja',
  },
  head: {
    title: 'スコアサーバー',
    titleTemplate: '%s | JANOG55 NETCON',
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      {
        hid: 'description',
        name: 'description',
        content: 'JANOG55 NETCON スコアサーバー',
      },
    ],
    link: [{ rel: 'icon', type: 'image/png', href: '/favicon.png' }],
  },
  css: ['~/assets/css/commons.sass'],
  build: {
    // Extend webpack config
    extend(config, { isDev, isClient }) {
      // Vue dev toolが使えなくなる
      // config.devtool = 'eval-source-map'
    },
  },
  loading: false,
  plugins: [
    '~/plugins/axios',
    '~/plugins/elvis',
    '~/plugins/eventsource',
    '~/plugins/json-storage',
    '~/plugins/mixins',
    '~/plugins/moment-update-locale',
    '~/plugins/push',
    '~/plugins/vue-clipboard',
    '~/plugins/vue-underscore',
    '~/plugins/vuex-orm',
  ],
  modules: ['@nuxtjs/axios', '@nuxtjs/markdownit', '@nuxtjs/proxy'],
  buildModules: ['@nuxtjs/moment', '@nuxtjs/vuetify'],

  // ---- Nuxtモジュールの設定 ----
  axios: {
    // Docs: https://axios.nuxtjs.org/options
    prefix: '/api',
    proxy: true,
  },
  markdownit: {
    // Docs: https://github.com/markdown-it/markdown-it
    preset: 'default',
    linkify: true,
    // スペース2つだけでなく、通常の改行でも開業するようになる
    breaks: true,
    // $mdを使えるようにする
    injected: true,
    use: [
      // マウスオーバーで正式名称を表示
      'markdown-it-abbr',
      // 絵文字:thinking_face:
      'markdown-it-emoji',
      // 補足を最下部に生成
      'markdown-it-footnote',
      // サニタイズ
      'markdown-it-sanitizer',
    ],
  },
  moment: {
    locales: ['es-us', 'ja'],
  },
  vuetify: {
    // customVariables: ['~/assets/css/variables.sass'],
    theme: {
      themes: {
        light: {
          primary: '#e40046',
          secondary: 'white',
        },
      },
    },
  },
}
