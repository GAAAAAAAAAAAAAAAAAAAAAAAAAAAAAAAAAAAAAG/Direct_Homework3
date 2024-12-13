#pragma once

#define FRAME_BUFFER_WIDTH		1280
#define FRAME_BUFFER_HEIGHT		720

#include "Timer.h"
#include "Player.h"
#include "Scene.h"
#include "UILayer.h"

//추가-
class UILayer;
//----

struct CB_FRAMEWORK_INFO
{
	float					m_fCurrentTime;
	float					m_fElapsedTime;
	float					m_fSecondsPerFirework = 1.0f;
	int						m_nFlareParticlesToEmit = 300;
	XMFLOAT3				m_xmf3Gravity = XMFLOAT3(0.0f, -9.8f, 0.0f);
	int						m_nMaxFlareType2Particles = 150;
};

class CGameFramework
{
public:
	CGameFramework();
	~CGameFramework();

	bool OnCreate(HINSTANCE hInstance, HWND hMainWnd);
	void OnDestroy();

	void CreateSwapChain();
	void CreateDirect3DDevice();
	void CreateCommandQueueAndList();

	void CreateRtvAndDsvDescriptorHeaps();

	void CreateRenderTargetViews();
	void CreateDepthStencilView();

	void ChangeSwapChainState();

	void BuildObjects();
	void ReleaseObjects();

	void ProcessInput();
	void AnimateObjects();
	void FrameAdvance();

	void WaitForGpuComplete();
	void MoveToNextFrame();

	//추가-------
#ifdef _WITH_DIRECT_WRITE_UI
	void UpdateUI();
#endif
	//-----------

	void OnProcessingMouseMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);
	void OnProcessingKeyboardMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);
	LRESULT CALLBACK OnProcessingWindowMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);

	// 추가 시도
	void ChangeScene();

	//추가2
	void CreateShaderVariables();
	void UpdateShaderVariables();
	void ReleaseShaderVariables();
	//
private:
	HINSTANCE					m_hInstance;
	HWND						m_hWnd;

	int							m_nWndClientWidth;
	int							m_nWndClientHeight;

	IDXGIFactory4* m_pdxgiFactory = NULL;
	IDXGISwapChain3* m_pdxgiSwapChain = NULL;
	ID3D12Device* m_pd3dDevice = NULL;

	bool						m_bMsaa4xEnable = false;
	UINT						m_nMsaa4xQualityLevels = 0;

	static const UINT			m_nSwapChainBuffers = 2;
	UINT						m_nSwapChainBufferIndex;

	ID3D12Resource* m_ppd3dSwapChainBackBuffers[m_nSwapChainBuffers];
	ID3D12DescriptorHeap* m_pd3dRtvDescriptorHeap = NULL;
	
	//추가2
	UINT						m_nRtvDescriptorIncrementSize;
	UINT						m_nDsvDescriptorIncrementSize;

	//

	ID3D12Resource* m_pd3dDepthStencilBuffer = NULL;
	ID3D12DescriptorHeap* m_pd3dDsvDescriptorHeap = NULL;

	ID3D12CommandAllocator* m_pd3dCommandAllocator = NULL;
	ID3D12CommandQueue* m_pd3dCommandQueue = NULL;
	ID3D12GraphicsCommandList* m_pd3dCommandList = NULL;

	ID3D12Fence* m_pd3dFence = NULL;
	UINT64						m_nFenceValues[m_nSwapChainBuffers];
	HANDLE						m_hFenceEvent;

	//추가----
	CGameObject* m_pLockedObject = NULL;
	//-------

	//추가-------
#ifdef _WITH_DIRECT_WRITE_UI

	UILayer* m_pUILayer = NULL;

	ID2D1SolidColorBrush* pd2dBrush;
	IDWriteTextFormat* pdwTextFormat;
	D2D1_RECT_F					d2dRect;

	bool						UIStart = false;
#endif

#if defined(_DEBUG)
	ID3D12Debug* m_pd3dDebugController;
#endif

	CGameTimer					m_GameTimer;

	CScene* m_pScene[2];
	int							n_Scene{};
	CPlayer* m_pPlayer = NULL;
	CCamera* m_pCamera = NULL;

	CShader* m_menu = NULL;
	bool						is_visiblity = false;

	POINT						m_ptOldCursorPos;

	_TCHAR						m_pszFrameRate[70];
	
	//추가2
	protected:
		ID3D12Resource* m_pd3dcbFrameworkInfo = NULL;
		CB_FRAMEWORK_INFO* m_pcbMappedFrameworkInfo = NULL;
};

