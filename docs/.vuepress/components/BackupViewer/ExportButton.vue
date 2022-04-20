<script lang="ts">
import { defineComponent, PropType } from "vue";
import { notify } from "@kyvg/vue3-notification";
import bplistParser from "bplist-parser";
import bplistCreator from "bplist-creator";
import { NineAnimatorBackup } from "./NineAnimatorBackup";

export default defineComponent({
  props: {
    userBackup: Object as PropType<NineAnimatorBackup[]>,
  },
  data() {
    return {
      exportUserBackup: [] as NineAnimatorBackup[] | undefined,
    };
  },
  mounted() {
    this.exportUserBackup = this.userBackup;
  },
  methods: {
    // Performance heavy function 😢, should only be used if needed, eg. exporting to JSON
    async recursiveParsePlist(object: any[] | Buffer): Promise<any[]> {
      if (Buffer.isBuffer(object)) {
        object = await bplistParser.parseFile(object);
      }

      await Object.keys(object).forEach(async (key) => {
        if (typeof object[key] === "object") {
          await this.recursiveParsePlist(object[key]);
        }
        if (object[key] instanceof Uint8Array) {
          object[key] = await bplistParser.parseFile(object[key]);
          await this.recursiveParsePlist(object[key]);
        }
      });

      return object;
    },

    async handleExport(type: string) {
      if (this.userBackup?.length) {
        var userBackupBuf;

        try {
          this.exportUserBackup![0]["exportedDate"] = new Date();

          if (type === "bplist") {
            // Creating the Plist buffer
            userBackupBuf = await bplistCreator(this.exportUserBackup!);
          } else if (type === "JSON") {
            userBackupBuf = await this.recursiveParsePlist(
              this.exportUserBackup!
            );
          }
          // Creating the file
          this.downloadBlob(
            type === "bplist" ? userBackupBuf : JSON.stringify(userBackupBuf),
            `${String(this.exportUserBackup![0]["exportedDate"])}.${
              type === "bplist" ? "naconfig" : "json"
            }`,
            type === "bplist" ? "application/octet-stream" : "application/json"
          );

          notify({
            type: "success",
            title: "⚠ Success: Backup Viewer",
            text: `Exported backup as ${
              type === "bplist" ? "naconfig" : "JSON"
            }`,
          });
        } catch (error) {
          console.error("Failed to parse data, something went wrong.");
          notify({
            type: "error",
            title: "🛑 Error: Backup Viewer",
            text: "Failed to parse data, something went wrong.",
          });
        }
      } else {
        notify({
          type: "warn",
          title: "⚠ Warning: Backup Viewer",
          text: "Upload a file first",
        });
      }
    },

    downloadURL(data, fileName) {
      const a = document.createElement("a");
      a.href = data;
      a.download = fileName;
      document.body.appendChild(a);
      a.style.display = "none";
      a.click();
      a.remove();
    },

    downloadBlob(data, fileName, mimeType) {
      // create a Blob from our buffer
      const blob = new Blob([data], {
        type: mimeType,
      });

      const url = window.URL.createObjectURL(blob);

      this.downloadURL(url, fileName);

      setTimeout(() => window.URL.revokeObjectURL(url), 1000);
    },
  },
});
</script>

<template>
  <span id="export-button">
    <button id="export-json-button" @click="handleExport('JSON')">
      Export JSON
    </button>

    <button @click="handleExport('bplist')">naconfig</button>
  </span>
</template>

<style scoped>
.top-right {
  position: absolute;
  top: 8px;
  right: 8px;
  cursor: pointer;
}

#export-button {
  float: right;
}
#export-button button {
  cursor: pointer;
  float: left;
  position: relative;
  color: #fff;
  padding: 0.6rem;
  border: none;
  background-color: #5a34b0;
}
#export-button button:hover {
  background-color: #673bcc;
}
#export-button button:nth-child(1) {
  border-top-left-radius: 10px;
  border-bottom-left-radius: 10px;
  border-right: solid 1px #fff;
}
#export-button button:nth-child(2) {
  border-top-right-radius: 10px;
  border-bottom-right-radius: 10px;
}
</style>
