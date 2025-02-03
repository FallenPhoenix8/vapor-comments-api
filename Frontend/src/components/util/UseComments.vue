<script setup lang="ts">
import { onMounted, ref } from "vue"
import Comment from "../../class/Comment"

const API_URL = import.meta.env.VITE_API_URL

const comments = ref<Comment[]>([])

const emit = defineEmits(["update:comments"])

onMounted(async () => {
  comments.value = await Comment.getApiComments()

  emit("update:comments", comments.value)

  const socket = new WebSocket(`${API_URL || ""}/ws/comments`)
  socket.onmessage = async ({ data }) => {
    comments.value = JSON.parse(await data.text()) as Comment[]

    emit("update:comments", comments.value)
  }
  console.log("Comments setup completed successfully.")
})
</script>
<template>
  <!-- Setting up comments -->
</template>
