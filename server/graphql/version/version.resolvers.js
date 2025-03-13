// graphql/version/version.resolvers.js
const fs = require('fs');
const path = require('path');
const Version = require('../../models/Version');

module.exports = {
  Query: {
    checkAPKVersion: async () => {
      // DB에서 버전 정보를 조회
      const doc = await Version.findOne({});
      if (!doc) {
        // 아직 버전 레코드가 없다면 기본값 "1.0.0"
        return '0.0.0';
      }
      return doc.version;
    },
  },

  Mutation: {
    // version.resolvers.js (uploadAPK)
    uploadAPK: async (_, { version, file }) => {
      console.log("==== [uploadAPK] START ====");
      console.log("version =", version);
      console.log("file argument =", file);

      // 1) 우선 file을 await
      const upload = await file;  
      // 2) upload.file 내부에서 실제 filename, createReadStream 등 추출
      const { filename, mimetype, encoding, createReadStream } = upload.file;

      console.log("filename =", filename);
      console.log("mimetype =", mimetype);
      console.log("encoding =", encoding);
      console.log("createReadStream =", createReadStream);

      if (!createReadStream) {
        throw new Error("createReadStream is missing");
      }

      const savePath = path.join(__dirname, '../../public_downloads', 'app.apk');

      return new Promise((resolve, reject) => {
        const readStream = createReadStream();
        const writeStream = fs.createWriteStream(savePath);

        readStream
          .pipe(writeStream)
          .on('finish', async () => {
            let doc = await Version.findOne({});
            if (!doc) {
              doc = new Version({ version });
            } else {
              doc.version = version;
            }
            await doc.save();

            console.log(`APK file saved: ${savePath}`);
            resolve(true);
          })
          .on('error', (err) => {
            console.error('File upload error:', err);
            reject(err);
          });
      });
    }

  },
};
