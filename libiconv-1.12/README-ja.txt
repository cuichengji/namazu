============================================================================
               GNU libiconv 1.12 + ���{��G���R�[�f�B���O�p�b�`
                                             -- x86 �Ńr���h���@ --

                    Copyright (C) 2008 AKANEIROSOFTWARE, Tadamasa Teranishi.
============================================================================
                                                   Last modified: 2008.09.19


�� 1. �͂��߂�
--------------

   GNU libiconv �ɓ��{��G���R�[�f�B���O�p�b�`�����Ă����̂ł��B
   (libiconv-1.12-ja-4.patch.gz)

   �܂��AWindows + VC++ ���ŃR���p�C�����邽�߂ɕK�v�� Makefile.msvc ���܂�
   �܂��B(--enable-extra-encodings �I�v�V�����w��)


�� 2. ���̃A�[�J�C�u�ȊO�ɕK�v�ȕ�
----------------------------------

* Microsoft Visual C++ 2005 �܂��� Microsoft Visual C++ 2008


�� 3. ���{��G���R�[�f�B���O�p�b�`�ɂ���
------------------------------------------

* libiconv �p�b�`�W
  <http://www2d.biglobe.ne.jp/~msyk/software/libiconv-patch.html>�ɂ���܂��B


�� 4. GNU libiconv �̃C���X�g�[��
---------------------------------

  �R�}���h�v�����v�g���J���A�R�}���h���C���ŃR���p�C�����s�����߂�
  vcvarsall.bat �����s���܂��B

  ��) Visual C++ 2005 �̏ꍇ

  ��������������������������������������������������������������������������
  ��C:\> cd "\Program Files\Microsoft Visual Studio 8\VC"                 ��
  ��C:\Program Files\Microsoft Visual Studio 8\VC> vcvarsall              ��
  ��������������������������������������������������������������������������

  libiconv-1.12.zip ���𓀂��A�R�}���h���C������ nmake �����s���܂��B

  ��������������������������������������������������������������������������
  ��C:\> cd \libiconv-1.12                                                ��
  ��C:\libiconv-1.12> set MFLAGS=-MT                                      ��
  ��C:\libiconv-1.12> set PREFIX=C:\usr                                   ��
  ��C:\libiconv-1.12> set NO_NLS=1                                        ��
  ��C:\libiconv-1.12> nmake /f Makefile.msvc clean                        ��
  ��C:\libiconv-1.12> nmake /f Makefile.msvc                              ��
  ��C:\libiconv-1.12> nmake /f Makefile.msvc install                      ��
  ��������������������������������������������������������������������������

  C:\usr\ �ȉ��ɃC���X�g�[������܂��B


�� 5. �Ɛ�
----------

  �{�A�[�J�C�u�͖��ۏ؂ł��B�Еz�ɂ������ẮA�s�ꐫ�y�ѓ���ړI�K�����ɂ�
  �Ă̈Öق̕ۏ؂��܂߂āA�����Ȃ�ۏ؂��s�Ȃ��܂���B


============================================================================
                    Copyright (C) 2008 AKANEIROSOFTWARE, Tadamasa Teranishi.
                                               <URI:http://www.akaneiro.jp/>
