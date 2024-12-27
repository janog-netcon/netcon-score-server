<template>
  <v-container justify-center fill-height>
    <v-form v-model="valid" @submit.prevent="submit">
      <v-text-field
        v-model="name"
        :rules="nameRules"
        label="ユーザ名"
        required
        autofocus
      >
      </v-text-field>

      <v-text-field
        v-model="password"
        :rules="passwordRules"
        :type="passwordVisible ? 'text' : 'password'"
        :append-icon="passwordVisible ? 'mdi-eye' : 'mdi-eye-off'"
        label="パスワード"
        required
        @click:append="passwordVisible = !passwordVisible"
      >
      </v-text-field>

      <v-btn
        :disabled="!valid"
        :loading="loading"
        type="submit"
        color="success"
        block
      >
        ログイン
      </v-btn>

      <v-btn
        to="/signup"
        color="info"
        nuxt
        block
        class="mt-2"
      >
        ユーザー作成
      </v-btn>
    </v-form>
  </v-container>
</template>
<script>
import { mapActions } from 'vuex'

export default {
  name: 'LoginPage',
  data() {
    return {
      valid: false,
      name: '',
      password: '',
      passwordVisible: false,
      loading: false,

      // 鬱陶しいのでメッセージは出さない
      nameRules: [(v) => !!v || ''],
      passwordRules: [(v) => !!v || ''],
    }
  },
  methods: {
    ...mapActions('session', ['login']),
    async submit() {
      this.loading = true

      if (await this.login({ name: this.name, password: this.password })) {
        this.notifySuccess({ message: 'ログインしました' })
        // locationを直接使うことで強制リロード
        // ストアもリセットされる
        window.location = '/guide/ja'
      } else {
        this.notifyWarning({
          message: 'ユーザ名かパスワードが正しくありません',
        })
      }

      this.loading = false
    },
  },
  head() {
    return {
      title: 'ログイン',
    }
  },
}
</script>
