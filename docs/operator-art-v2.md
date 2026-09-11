# 오퍼레이터 v2 · 22세 성인 인상과 남색 브릿지

- 사용자 요청: 큰 눈, 더 귀엽고 22살 같은 성인 캐릭터 인상. 기존 헤어스타일에 남색 브릿지 추가.
- 적용 파일: Resources/Assets.xcassets/OperatorCutout.imageset/operator-cutout.png (1024×1536, RGBA).
- 기존 헤어스타일·흰 셔츠·검은 넥타이·금색 휘장·이어캡 포즈 유지. 눈과 얼굴 비율을 조정하고 흑발에 남색 가닥을 넣었습니다.
- 내장 image_gen으로 제작/편집. 투명 배경 대신 체크무늬를 생성해, 사용자가 명시적으로 승인한 Python 배경 제거를 후처리로 사용했습니다.
- rembg 2.0.84 / isnet-anime, CPUExecutionProvider, decontaminate=True. 실제 alpha 0~255, 어두운 배경에서 가장자리 검토.
- 라이브러리 https://github.com/danielgatis/rembg (MIT). 모델 출처 https://github.com/SkyTNT/anime-segmentation (Apache-2.0 표기).

## 최종 내장 도구 프롬프트
Use case: precise-object-edit. Keep this exact young ADULT 22-year-old Hunter Run woman, her large sparkling eyes, facial proportions, small warm smile, hairstyle shape, body, white shirt and black tie, gold insignia, earpiece hand pose, framing and art style unchanged. Add only a few tasteful DARK NAVY BLUE highlight streaks woven through the dark face-framing hair and side lengths. Her hair remains predominantly black; the navy streaks are subtle yet visibly blue in the light, not neon, not cyan, not the whole head dyed. No other character changes. Replace the checkered background and the faint background swirls with a perfectly flat solid neutral light gray #D8D8D8 background to make subsequent local background removal clean. No scenery, gradient, grid, words, UI or other objects. Same 1024 by 1536 portrait composition.

## 얼굴 수정 프롬프트
Use case: identity-preserve with explicit age-styling and face redesign. Edit the supplied Hunter Run operator sprite to look like a clearly ADULT 22-year-old woman, more charming and cute than the reference's mature late-twenties look. USER CORRECTION: changing the smile alone is insufficient. Make her eyes visibly larger and more rounded, sparkling grey-blue anime eyes with softer upper lids and a friendly lively gaze. Slightly fuller soft cheeks, shorter softer lower-face proportions, gently rounded jawline, less angular face, delicate natural nose, rosy cheeks and a sunny small confident smile. Aim for a cute youthful adult anime game heroine who sounds bright, warm and helpful. Preserve recognizable dark shoulder-length side-parted hair, adult body proportions, white rolled-sleeve shirt, black necktie, gold insignia, black belted trousers, wristwatch and earpiece. Preserve same pose, one hand naturally touching the earpiece and other hand in trouser pocket. Keep her upright, same camera, same full-head to mid-thigh framing, both elbows inside frame and natural fingers. Match the polished semi-realistic Korean anime game art style but let the FACE be distinctly cuter and youthful with larger eyes. Do not make a child, chibi or schoolgirl; she is a working adult aged 22. No new accessories or text. Deliver this character isolated on a REAL transparent alpha background, preserve input alpha background rather than rendering a checker pattern. No background scenery, checkerboard, gray tiles, colored backdrop, fog or halo outside her silhouette.

Alpha cleanup: values <=3 set to 0 and >=252 to 255; intermediate edge alpha retained. Verified transparent corners, opaque interior and dark composite.
