<script setup lang="ts">
import { Buffer } from "buffer";
import { ref, reactive, computed, onMounted } from "vue";
import { notify } from "@kyvg/vue3-notification";
import bplistParser from "bplist-parser";
// import bplistCreator from "bplist-creator";

interface NineAnimatorBackup {
  exportedDate: string;
  progresses: { [key: string]: number };
  trackingData: TrackingDatum[] | Uint8Array;
  subscriptions: AnimeLink[];
  history: AnimeLink[];
}

interface AnimeLink {
  title: string;
  source: string;
  image: Link;
  link: Link;
}

interface TrackingDatum {
  title?: string;
  source?: string;
  image?: Link;
  link?: Link;
  data?: number[];
}

interface Link {
  relative: string;
}

var fileReader;
const tabs = ["history", "subscriptions"];
const trackSerialized = new Set();
const currentTab = ref("history");
const file = ref<File | null>();
const backupData: { data: NineAnimatorBackup[] } = reactive({
  data: [],
});
const searchState: { filteredData: AnimeLink[]; query: string } = reactive({
  filteredData: [],
  query: "",
});
const hasSearchResults = computed(() => {
  return searchState.filteredData && searchState.query !== "";
});
const resultData = computed(() => {
  return hasSearchResults.value
    ? searchState.filteredData
    : backupData.data[0][currentTab.value];
});

// Performance heavy function 😢, should only be used if needed, eg. exporting to JSON
async function recursiveParsePlist(object: any[] | Buffer): Promise<any[]> {
  if (Buffer.isBuffer(object)) {
    object = await bplistParser.parseFile(object);
  }

  await Object.keys(object).forEach(async (key) => {
    if (typeof object[key] === "object") {
      await recursiveParsePlist(object[key]);
    }
    if (object[key] instanceof Uint8Array) {
      // We know that trackingData has a nested serialized trackingContext and non-serialized AnimeLink
      // Hence, we assume that all nested serialized data are from trackingData, trackingContext
      // Used to keep track which data are serialized so that we can serialize them when exporting
      trackSerialized.add(key);

      object[key] = await bplistParser.parseFile(object[key]);
      await recursiveParsePlist(object[key]);
    }
  });

  return object;
}

async function handleFileRead($event: Event) {
  // Create the Uint8 Array from the uploaded file Array Buffer
  let arrayBuffer: Uint8Array = new Uint8Array(
    fileReader.result as ArrayBuffer
  );
  // Make it into a Buffer
  let buffer: Buffer = Buffer.from(arrayBuffer);

  try {
    let data: NineAnimatorBackup[] = await bplistParser.parseFile(buffer);
    if (data) {
      // console.info("[DEBUG]: ", new Date(), data);

      backupData.data = data;
    }
  } catch (error) {
    console.error("Failed to parse data, something went wrong.");
    notify({
      type: "error",
      title: "🛑 Error: Backup Viewer",
      text: "Failed to parse data, something went wrong.",
    });
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

    if (
      fileReader &&
      file.value instanceof Blob &&
      file.value.name.toLowerCase().endsWith(".naconfig")
    ) {
      fileReader.readAsArrayBuffer(file.value);
    } else {
      notify({
        type: "warn",
        title: "⚠ Warning: Backup Viewer",
        text: "Invalid file format",
      });
    }
  }
}

function handleSearchInput($event: Event) {
  const target = $event.target as HTMLInputElement;
  const query = target.value.trim();

  const filteredData = backupData.data[0][currentTab.value].filter((data) => {
    const { title, source } = data;
    return (
      title.toLowerCase().includes(query.toLowerCase()) ||
      source.toLowerCase().includes(query.toLowerCase())
    );
  });

  searchState.query = query;
  searchState.filteredData = filteredData;
}

function editAnimeLink(data) {
  notify({
    type: "warn",
    title: "⚠ Warning: Backup Viewer",
    text: "Not yet implemented",
  });
}

// lifecycle hooks
onMounted(() => {
  fileReader = new window.FileReader();
});
</script>

<template>
  <notifications
    position="top right"
    :style="{
      marginTop: '57.5938px',
    }"
  />

  <!-- TODO: Export, Clicking into an anime pops up a modal for you to edit  -->
  <h2>
    <svg id="svg__gooey" xmlns="http://www.w3.org/2000/svg" version="1.1">
      <defs>
        <filter id="gooey">
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

    <span id="svg-wrapper">
      <button id="gooey__button" @click="onChooseFile" filter="url(#gooey)">
        Upload
        <span class="bubbles">
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
        </span>
      </button>
    </span>

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

  <div v-if="backupData.data.length">
    <div class="tabs">
      <div
        v-for="(tab, index) in tabs"
        class="tab"
        :key="tab"
        v-on:click="(currentTab = tab) && (searchState.query = '')"
      >
        <label :for="`tabs2-${index}`">
          {{ tab && tab.charAt(0).toUpperCase() + tab.slice(1) }}</label
        >
        <input
          :id="`tabs2-${index}`"
          name="tabs-two"
          type="radio"
          :checked="index == 0 ? 'checked' : null"
        />
      </div>
    </div>

    <div id="content-container">
      <h2>
        Exported on
        {{ backupData.data[0]?.exportedDate?.toDateString() }}
      </h2>
      <form
        class="search-box"
        role="search"
        :style="{
          display: 'block',
          marginRight: '19.2px',
        }"
      >
        <input
          id="search-input"
          type="text"
          placeholder="Search..."
          aria-label="Search"
          :style="{ width: '100%' }"
          @input="handleSearchInput"
        />
      </form>
      <div class="cards">
        <h2 v-if="!resultData.length">No data</h2>
        <div
          class="card"
          v-for="(value, index) in resultData"
          :key="`${value.title}-${value.source}-${index}`"
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
                <path>
                  <animate
                    attributeName="d"
                    values="M 40 80 c 22 0 40 -22 40 -40 v 40 Z"
                  />
                </path>
              </svg>
              <div class="card__header-text">
                <h3 class="card__title">{{ value.title }}</h3>
                <span class="card__status">{{ value.source }}</span>
              </div>
              <span
                id="editButton"
                class="top-right"
                @click="editAnimeLink(value)"
              >
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="#000000"
                  fill="none"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                  <path
                    d="M4 20h4l10.5 -10.5a1.5 1.5 0 0 0 -4 -4l-10.5 10.5v4"
                  />
                  <line x1="13.5" y1="6.5" x2="17.5" y2="10.5" />
                </svg>
              </span>
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
  </div>
</template>

<style scoped>
@import "./BackupViewer.css";
</style>
