console.log("it works")

let data = []

const socket = new WebSocket("/ws")
socket.onmessage = async ({ data }) => {
  data = JSON.parse(await data.text())
  console.log(data)
}

document.querySelector("button").onclick = () => {
  socket.send("hey")
}
