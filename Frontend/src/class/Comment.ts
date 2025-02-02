import axios, { type AxiosResponse } from "axios"

export default class Comment {
  id: number
  content: string
  static comments: Comment[] = []

  private static API_URL = import.meta.env.VITE_API_URL

  constructor(id: number, content: string) {
    this.id = id
    this.content = content
  }

  static async getApiComments() {
    let res: AxiosResponse | null = null
    try {
      res = await axios.get(`${Comment.API_URL}/api/comments`, {
        headers: {
          "Access-Control-Allow-Origin": "*",
        },
      })
    } catch (err) {
      console.error(err)
    }

    if (!(res?.status === 200)) {
      throw new Error("Failed to fetch comments")
    }

    this.comments = res.data
    return res.data as Comment[]
  }
}
