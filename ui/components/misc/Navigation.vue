<template>
  <v-app-bar app dense color="secondary">
    <navigation-link to="/" active-class="" class="mr-2 ml-1">
      <v-img
        :src="require('~/assets/img/janog49_logo_96.png')"
        height="48"
        width="259"
        class="my-2"
        alt="JANOG49"
      />
    </navigation-link>

    <div style="font-weight: bold; margin-top: auto; margin-bottom: 5px; margin-left: 5px;">Sponsored by:</div>
    <v-btn href="https://www.ntt.com/index.html" class="black--text mr-1 px-0" tile text height="48px" min-width="106px">
      <img
        :src="require('~/assets/img/janog49_docomobusiness_96.png')"
        height="48"
        alt="NTTコミュニケーションズ"
      />
    </v-btn>
    <v-btn href="https://www.haradacorp.co.jp/" class="black--text mr-1 px-0" tile text height="48px" min-width="96px">
      <img
        :src="require('~/assets/img/janog49_harada_96.png')"
        height="48"
        alt="HARADA CORPORATION"
      />
    </v-btn>

    <v-spacer />

    <template v-if="isWide">
      <navigation-link
        v-for="nav in navigations"
        :key="nav.key"
        :to="nav.to"
        :always="nav.always"
        @click="nav.click"
      >
        <v-icon v-if="nav.icon">{{ nav.icon }}</v-icon>
        <div v-else>{{ nav.text }}</div>
      </navigation-link>
    </template>
    <template v-else>
      <v-menu open-on-hover offset-y>
        <template v-slot:activator="{ on }">
          <!-- divで囲まないと余白が崩れる -->
          <div>
            <v-app-bar-nav-icon
              :ripple="false"
              color="black"
              text
              tile
              v-on="on"
            />
          </div>
        </template>

        <v-list>
          <v-list-item
            v-for="nav in navigations"
            :key="nav.key"
            :to="nav.to"
            :always="nav.always"
            @click="nav.click"
          >
            <v-list-item-title>
              <v-icon v-if="nav.icon" color="black">{{ nav.icon }}</v-icon>
              <div v-else>{{ nav.text }}</div>
            </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </template>
  </v-app-bar>
</template>
<script>
import { mapActions } from 'vuex'
import NavigationLink from '~/components/misc/NavigationLink'

export default {
  name: 'Navigation',
  components: {
    NavigationLink,
  },
  data() {
    return {
      isWide: true,
    }
  },
  computed: {
    navigations() {
      return this.navigationsBase
        .filter((nav) => (nav.if !== undefined ? nav.if : true))
        .map((nav) => {
          nav.key = nav.text || nav.icon
          nav.always = nav.always !== undefined ? nav.always : false
          nav.click = nav.click ? nav.click : () => {}
          return nav
        })
    },
    navigationsBase() {
      return [
        { to: '/', text: 'トップ' },
        { to: '/problems', text: '問題' },
        { to: '/issues', text: '質問' },
        { to: '/answers', text: '解答', if: this.isNotPlayer },
        { to: '/summary', text: '状況', if: this.isNotPlayer },
        { to: '/guide', text: 'ガイド' },
        { to: '/teams', text: 'ユーザ' },
        { to: '/settings', icon: 'mdi-cog-outline', if: this.isStaff },
        {
          to: '/login',
          text: 'ログイン',
          if: this.isNotLoggedIn,
          always: true,
        },
        {
          to: '/login',
          icon: 'mdi-exit-run',
          if: this.isLoggedIn,
          click: this.tryLogout,
        },
      ]
    },
    wideThreshold() {
      // 未ログインかプレイヤーなら後者
      return this.isStaff || this.isAudience ? 690 : 510
    },
  },
  watch: {
    isLoggedIn: {
      immediate: true,
      handler(value) {
        this.onResize()
      },
    },
  },
  beforeMount() {
    window.addEventListener('resize', this.onResize, { passive: true })
  },
  beforeDestroy() {
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', this.onResize, { passive: true })
    }
  },
  methods: {
    ...mapActions('session', ['logout']),

    async tryLogout() {
      if (await this.logout()) {
        this.notifySuccess({ message: 'ログアウトしました' })
        this.$router.push('/login')
      } else {
        this.notifyWarning({ message: 'ログインしていません' })
      }
    },
    onResize() {
      this.isWide = window.innerWidth >= this.wideThreshold
    },
  },
}
</script>
<style scoped lang="sass">
::v-deep
  .v-toolbar__content
    padding: 0px

  // よくわからんけどこれをつけるとアクティブリンクの色が直る
  .theme--light.v-btn--active::before
    opacity: 0
</style>
