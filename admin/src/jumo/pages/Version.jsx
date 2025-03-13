import React, { useState } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import { Header } from '../components'; // 예: 상단 제목바
import { CHECK_APK_VERSION } from '../graphql/queries';
import { UPLOAD_APK } from '../graphql/mutations';

function Version() {
  // 현재 버전 조회
  const { data, loading, error, refetch } = useQuery(CHECK_APK_VERSION, {
    fetchPolicy: 'no-cache',
  });

  // 업로드 Mutation
  const [uploadApkMutation] = useMutation(UPLOAD_APK);

  // Form state
  const [versionName, setVersionName] = useState('');
  const [file, setFile] = useState(null);

  // 파일 input onChange 핸들러
  const handleFileChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
    }
  };

  // 업로드 버튼
  const handleUpload = async () => {
    if (!versionName.trim() || !file) {
      alert('버전명과 파일을 입력하세요.');
      return;
    }

    try {
      // GraphQL Upload 규칙에 따라 variables에 넣으면 됩니다.
      await uploadApkMutation({
        variables: {
          version: versionName,
          file,
        },
      });
      alert('업로드 완료!');
      setVersionName('');
      setFile(null);
      // 새 버전 표시 위해 refetch
      await refetch();
    } catch (err) {
      alert(err.message);
    }
  };

  const currentVersion = data?.checkAPKVersion || '(없음)';
  const downloadLink = 'https://jumo-vs8e.onrender.com/download/app.apk'; 
  // 실제 서버 주소나 .env 파일 등을 참고하여 변경

  return (
    <div className="m-2 p-2 bg-white rounded-2xl shadow-xl">
      <Header category="Page" title="APK 버전 관리" />

      {loading && <p>Loading...</p>}
      {error && <p className="text-red-500">{error.message}</p>}

      {!loading && !error && (
        <div className="flex flex-col gap-4">
          <div className="border p-3 rounded">
            <h2 className="text-lg font-bold mb-2">현재 버전</h2>
            <p>버전명: <strong>{currentVersion}</strong></p>
            <p>다운로드 링크: 
              <a
                href={downloadLink}
                className="text-blue-600 underline ml-2"
                target="_blank"
                rel="noreferrer"
              >
                {downloadLink}
              </a>
            </p>
          </div>

          <div className="border p-3 rounded">
            <h2 className="text-lg font-bold mb-2">신규 버전 업로드</h2>
            <div className="flex flex-col gap-2">
              <div>
                <label className="mr-2">버전명:</label>
                <input
                  className="border p-1 rounded"
                  type="text"
                  value={versionName}
                  onChange={(e) => setVersionName(e.target.value)}
                  placeholder="예: 1.0.5"
                />
              </div>
              <div>
                <label className="mr-2">파일:</label>
                <input
                  type="file"
                  onChange={handleFileChange}
                  accept=".apk"
                />
              </div>
              <div>
                <button
                  className="bg-blue-500 text-white px-3 py-1 rounded"
                  onClick={handleUpload}
                >
                  업로드
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Version;
