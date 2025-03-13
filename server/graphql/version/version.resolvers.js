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
    uploadAPK: async (_, { version, file }) => {
      try{


        console.log("==== [uploadAPK] START ====");
        console.log("version =", version);
        console.log("file argument =", file);
        
        const { createReadStream } = await file;


        console.log("filename =", filename);
        console.log("mimetype =", mimetype);
        console.log("encoding =", encoding);
        console.log("createReadStream =", createReadStream);
        
        const savePath = path.join(__dirname, '../../public_downloads', 'app.apk');

        return new Promise((resolve, reject) => {

          if (!createReadStream) {
            console.error("❌ createReadStream is null/undefined!");
            reject(new Error("createReadStream is missing"));
            return;
          }

          const readStream = createReadStream();
          const writeStream = fs.createWriteStream(savePath);

          readStream
            .pipe(writeStream)
            .on('finish', async () => {
              // 파일 저장이 끝나면 DB에 버전 기록
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
      } catch (error) {
        console.error("❌ [uploadAPK] error:", error);
        throw error;
      }
    }
  },
};
