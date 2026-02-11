# 라이선스 관리

## Gist URL
https://gist.github.com/WhiteDragonGroup/54060d3af211a6d5ba45dcb5fd01d148

## 게임 끄기 (돈 안 낼 때)
```
gh api gists/54060d3af211a6d5ba45dcb5fd01d148 -X PATCH -f 'files[allowed_places.txt][content]= '
```

## 게임 켜기
```
gh api gists/54060d3af211a6d5ba45dcb5fd01d148 -X PATCH -f 'files[allowed_places.txt][content]=MyVillage'
```

## 작동 원리
- Gist에 `MyVillage`가 있으면 게임 작동
- 없으면 서버 스크립트 비활성화 + 플레이어 킥
- 서버 시작 시 + 5분마다 재검증
- Studio 테스트(PlaceId 0)는 항상 허용
