<script setup lang="ts">
// import Modal from "./Modal.vue";
import { Buffer } from "buffer";
import { ref, reactive, onMounted } from "vue";
import bplistParser from "bplist-parser";
// import bplistCreator from "bplist-creator";

var fileReader;
const modalActive = ref(false);
const file = ref<File | Blob | null>();
const myObject: { title: string; data: [any?] } = reactive({
  title: "How to do lists in Vue",
  data: [],
});

const toggleModal = () => {
  modalActive.value = !modalActive.value;
};

async function handleFileRead($event: Event) {
  // Create the Uint8 Array from the uploaded file Array Buffer
  let arrayBuffer: Uint8Array = new Uint8Array(
    fileReader.result as ArrayBuffer
  );
  // Make it into a Buffer
  let buffer: Buffer = Buffer.from(arrayBuffer);

  try {
    let data = await bplistParser.parseFile(buffer);
    if (data) {
      console.info("[DEBUG]: ", new Date(), data);
      myObject.data = data;
    }
  } catch (error) {
    console.error("Failed to parse data, something went wrong.");
  }
}

function onChooseFile($event: Event) {
  document.getElementById("fileUpload")!.click();
}

function onFileChanged($event: Event) {
  const target = $event.target as HTMLInputElement;
  if (target && target.files) {
    file.value = target.files[0];

    fileReader.onloadend = handleFileRead;
    if (fileReader && file.value instanceof Blob) {
      fileReader.readAsArrayBuffer(file.value);
    }
  }
}

// lifecycle hooks
onMounted(() => {
  fileReader = new window.FileReader();
});
</script>

<template>
  <!-- TODO: Search Bar | Upload | Export -->
  <!-- The Library UI, with tabs to change lists -->
  <!-- Clicking into an anime pops up a modal for you to edit -->

  <div v-if="myObject.data.length > 0">
    <h2>History</h2>
    <div class="cards">
      <div
        class="card"
        v-for="value in myObject.data[0]?.history"
        :key="value.title"
      >
        <img
          v-if="value.image?.relative !== undefined"
          class="card__image"
          alt=""
          v-lazy="{
            src: value.image?.relative,
            loading:
              'https://c.tenor.com/RgF5keyruhcAAAAM/alex-geerken-geerken.gif',
            error:
              'https://9ani.app/static/resources/artwork_not_available.jpg',
          }"
        />
        <div class="card__overlay">
          <div class="card__header">
            <svg class="card__arc" xmlns="http://www.w3.org/2000/svg">
              <path />
            </svg>
            <div class="card__header-text">
              <h3 class="card__title">{{ value.title }}</h3>
              <span class="card__status">{{ value.source }}</span>
            </div>
          </div>
          <a
            class="card__description"
            :href="value.link?.relative"
            target="_blank"
            rel="noreferrer noopener"
          >
            {{ value.link?.relative }}
          </a>
        </div>
      </div>
    </div>
  </div>
  <div v-else>
    <h2>
      <svg id="svg__gooey" xmlns="http://www.w3.org/2000/svg" version="1.1">
        <defs>
          <filter id="gooey">
            <!-- in="sourceGraphic" -->
            <feGaussianBlur in="SourceGraphic" stdDeviation="5" result="blur" />
            <feColorMatrix
              in="blur"
              type="matrix"
              values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 19 -9"
              result="highContrastGraphic"
            />
            <feComposite
              in="SourceGraphic"
              in2="highContrastGraphic"
              operator="atop"
            />
          </filter>
        </defs>
      </svg>

      <button id="gooey-button" @click="onChooseFile">
        Upload
        <span class="bubbles">
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
        </span>
      </button>
      <input
        id="fileUpload"
        type="file"
        @change="onFileChanged($event)"
        accept=".naconfig"
      />
      a NineAnimator
      <code>.naConfig</code>
      backup
    </h2>
  </div>
</template>

<style scoped>
h2 {
  border-bottom: none;
}

svg#svg__gooey {
  position: absolute;
  top: -4000px;
  left: -4000px;
}

#gooey-button {
  cursor: pointer;
  padding: 0.6rem;
  font-size: 1.25rem;
  border: none;
  color: #adbac7;
  filter: url("#gooey");
  position: relative;
  background-color: #5a34b0;
}

#gooey-button:hover {
  background-color: #673bcc;
}

#gooey-button:focus {
  outline: none;
}
#gooey-button .bubbles {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
}
#gooey-button .bubbles .bubble {
  background-color: #5a34b0;
  border-radius: 100%;
  position: absolute;
  top: 0;
  left: 0;
  display: block;
  z-index: -1;
}
#gooey-button .bubbles .bubble:nth-child(1) {
  left: 31px;
  width: 25px;
  height: 25px;
  animation: move-1 3.06s infinite;
  animation-delay: 0.6s;
}
#gooey-button .bubbles .bubble:nth-child(2) {
  left: 22px;
  width: 25px;
  height: 25px;
  animation: move-2 3.08s infinite;
  animation-delay: 0.8s;
}
#gooey-button .bubbles .bubble:nth-child(3) {
  left: 42px;
  width: 25px;
  height: 25px;
  animation: move-3 3.1s infinite;
  animation-delay: 1s;
}

#gooey-button .bubbles .bubble:nth-child(4) {
  left: 19px;
  width: 25px;
  height: 25px;
  animation: move-4 3.16s infinite;
  animation-delay: 1.6s;
}

#gooey-button .bubbles .bubble:nth-child(5) {
  left: 11px;
  width: 25px;
  height: 25px;
  animation: move-5 3.2s infinite;
  animation-delay: 2s;
}

@keyframes move-1 {
  0% {
    transform: translate(0, 0);
  }
  99% {
    transform: translate(0, -51px);
  }
  100% {
    transform: translate(0, 0);
    opacity: 0;
  }
}

@keyframes move-2 {
  0% {
    transform: translate(0, 0);
  }
  99% {
    transform: translate(0, -122px);
  }
  100% {
    transform: translate(0, 0);
    opacity: 0;
  }
}

@keyframes move-3 {
  0% {
    transform: translate(0, 0);
  }
  99% {
    transform: translate(0, -105px);
  }
  100% {
    transform: translate(0, 0);
    opacity: 0;
  }
}

@keyframes move-4 {
  0% {
    transform: translate(0, 0);
  }
  99% {
    transform: translate(0, -103px);
  }
  100% {
    transform: translate(0, 0);
    opacity: 0;
  }
}

@keyframes move-5 {
  0% {
    transform: translate(0, 0);
  }
  99% {
    transform: translate(0, -107px);
  }
  100% {
    transform: translate(0, 0);
    opacity: 0;
  }
}

#fileUpload {
  display: none;
}

.cards {
  margin: 2rem 1vw;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 2rem;
  padding: 0;
  list-style-type: none;
}

.card {
  position: relative;
  display: block;
  height: 100%;
  border-radius: calc(40 * 1px);
  overflow: hidden;
  text-decoration: none;
}

.card__image {
  width: 100%;
  height: auto;
}

.card__overlay {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 1;
  border-radius: calc(40 * 1px);
  transform: translateY(100%);
  transition: 0.2s ease-in-out;
  background-color: #22272e;
}

.card:hover .card__overlay {
  transform: translateY(0);
}

.card__header {
  position: relative;
  display: flex;
  align-items: center;
  gap: 2em;
  padding: 1em 2em;
  border-radius: calc(40 * 1px) 0 0 0;
  transform: translateY(-100%);
  transition: 0.2s ease-in-out;
  background-color: #22272e;
}

html.dark .card__header,
html.dark .card__overlay {
  background-color: #fff;
}

.card__arc {
  width: 80px;
  height: 80px;
  position: absolute;
  right: 0;
  z-index: 1;
  /* hacky way to remove gap between .card__header and the svg */
  bottom: calc(100% - 1px);
}

.card__arc path {
  fill: #22272e;
  d: path("M 40 80 c 22 0 40 -22 40 -40 v 40 Z");
}

html.dark .card__arc path {
  fill: #fff;
}

.card:hover .card__header {
  transform: translateY(0);
}

.card__thumb {
  flex-shrink: 0;
  width: 50px;
  height: 50px;
  border-radius: 50%;
}

.card__title {
  font-size: 1rem;
  margin: 0 0 0.3em;
  color: #e6e6e6;
}

.card__tagline {
  display: block;
  margin: 1em 0;
  font-size: 0.8rem;
  color: #bbbbbb;
}

.card__status {
  font-size: 0.8rem;
  color: #bbbbbb;
}

.card__description {
  font-size: 0.8rem;
  padding: 0 2em 2em;
  margin: 0;
  color: #bbbbbb;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
  overflow: hidden;
}

html.dark .card__title {
  color: #2c2c2c;
}

html.dark .card__tagline html.dark .card__status,
html.dark .card__description {
  color: #585858;
}
</style>
